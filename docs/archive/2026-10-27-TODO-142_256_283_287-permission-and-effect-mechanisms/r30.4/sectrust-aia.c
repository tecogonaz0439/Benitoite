#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static SecCertificateRef certificate(const char *path) {
    FILE *file = fopen(path, "rb");
    if (file == NULL) exit(20);
    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    if (length < 0) exit(21);
    rewind(file);
    unsigned char *bytes = malloc((size_t)length);
    if (bytes == NULL || fread(bytes, 1, (size_t)length, file) != (size_t)length) exit(22);
    fclose(file);
    CFDataRef data = CFDataCreate(NULL, bytes, length);
    free(bytes);
    SecCertificateRef cert = SecCertificateCreateWithData(NULL, data);
    CFRelease(data);
    if (cert == NULL) exit(23);
    return cert;
}

int main(int argc, char **argv) {
    if (argc != 4) return 24;
    SecCertificateRef leaf = certificate(argv[1]);
    SecCertificateRef root = certificate(argv[2]);
    SecPolicyRef policy = SecPolicyCreateSSL(true, CFSTR("localhost"));
    SecTrustRef trust = NULL;
    OSStatus created = SecTrustCreateWithCertificates(leaf, policy, &trust);
    if (created != errSecSuccess) return 25;
    Boolean allowed = false;
    OSStatus queried = SecTrustGetNetworkFetchAllowed(trust, &allowed);
    printf("default_fetch_status=%d default_fetch_allowed=%d\n", (int)queried, (int)allowed);
    CFArrayRef anchors = CFArrayCreate(NULL, (const void **)&root, 1, &kCFTypeArrayCallBacks);
    OSStatus anchored = SecTrustSetAnchorCertificates(trust, anchors);
    OSStatus only = SecTrustSetAnchorCertificatesOnly(trust, true);
    if (anchored != errSecSuccess || only != errSecSuccess) return 26;
    if (strcmp(argv[3], "disabled") == 0) {
        OSStatus disabled = SecTrustSetNetworkFetchAllowed(trust, false);
        if (disabled != errSecSuccess) return 27;
    }
    SecTrustGetNetworkFetchAllowed(trust, &allowed);
    printf("effective_fetch_allowed=%d\n", (int)allowed);
    fflush(stdout);
    CFErrorRef error = NULL;
    Boolean verified = SecTrustEvaluateWithError(trust, &error);
    printf("verified=%d error_code=%ld\n", (int)verified,
           error == NULL ? 0L : (long)CFErrorGetCode(error));
    if (error != NULL) CFRelease(error);
    CFRelease(anchors);
    CFRelease(trust);
    CFRelease(policy);
    CFRelease(root);
    CFRelease(leaf);
    return 0;
}
