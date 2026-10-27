"""検査を時間上限で止め、子の終了を確認してから呼び出し元へ戻す。"""
import os
import signal
import subprocess


def run(command, *, cwd, timeout, env=None):
    process = subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, start_new_session=True)
    try:
        output, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            output, _ = process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            output, _ = process.communicate()
        return subprocess.CompletedProcess(command, 124,
            output + f'\n時間上限 {timeout} 秒でプロセス群を停止し、終了を確認した。\n')
    except BaseException:
        os.killpg(process.pid, signal.SIGKILL)
        process.communicate()
        raise
    return subprocess.CompletedProcess(command, process.returncode, output)
