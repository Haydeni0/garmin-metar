# /// script
# dependencies = [
#   "pillow>=10.0.0",
#   "typer>=0.12.0",
# ]
# ///
import ctypes
import os
import socket
import subprocess
import threading
import time
from pathlib import Path
from PIL import Image
import typer

app = typer.Typer(help="Connect IQ build, test, and visual simulator capture tool")

kernel32 = ctypes.windll.kernel32
user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32


def find_sdk_bin(custom_sdk: Path | None = None) -> Path:
    if custom_sdk is not None:
        bin_dir = custom_sdk / "bin"
        if bin_dir.is_dir():
            return bin_dir
        return custom_sdk

    appdata = os.environ.get("APPDATA")
    if not appdata:
        raise RuntimeError("APPDATA environment variable not set")

    sdks_dir = Path(appdata) / "Garmin" / "ConnectIQ" / "Sdks"
    if not sdks_dir.is_dir():
        raise FileNotFoundError(f"Connect IQ SDKs directory not found: {sdks_dir}")

    sdks = sorted(sdks_dir.glob("connectiq-sdk-*"), reverse=True)
    if not sdks:
        raise FileNotFoundError(f"No Connect IQ SDK found in {sdks_dir}")

    return sdks[0] / "bin"


class STARTUPINFO(ctypes.Structure):
    _fields_ = [
        ("cb", ctypes.c_uint32),
        ("lpReserved", ctypes.c_wchar_p),
        ("lpDesktop", ctypes.c_wchar_p),
        ("lpTitle", ctypes.c_wchar_p),
        ("dwX", ctypes.c_uint32),
        ("dwY", ctypes.c_uint32),
        ("dwXSize", ctypes.c_uint32),
        ("dwYSize", ctypes.c_uint32),
        ("dwXCountChars", ctypes.c_uint32),
        ("dwYCountChars", ctypes.c_uint32),
        ("dwFillAttribute", ctypes.c_uint32),
        ("dwFlags", ctypes.c_uint32),
        ("wShowWindow", ctypes.c_uint16),
        ("cbReserved2", ctypes.c_uint16),
        ("lpReserved2", ctypes.c_void_p),
        ("hStdInput", ctypes.c_void_p),
        ("hStdOutput", ctypes.c_void_p),
        ("hStdError", ctypes.c_void_p),
    ]


class PROCESS_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("hProcess", ctypes.c_void_p),
        ("hThread", ctypes.c_void_p),
        ("dwProcessId", ctypes.c_uint32),
        ("dwThreadId", ctypes.c_uint32),
    ]


class RECT(ctypes.Structure):
    _fields_ = [
        ("left", ctypes.c_long),
        ("top", ctypes.c_long),
        ("right", ctypes.c_long),
        ("bottom", ctypes.c_long),
    ]


class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [
        ("biSize", ctypes.c_uint32),
        ("biWidth", ctypes.c_int32),
        ("biHeight", ctypes.c_int32),
        ("biPlanes", ctypes.c_uint16),
        ("biBitCount", ctypes.c_uint16),
        ("biCompression", ctypes.c_uint32),
        ("biSizeImage", ctypes.c_uint32),
        ("biXPelsPerMeter", ctypes.c_int32),
        ("biYPelsPerMeter", ctypes.c_int32),
        ("biClrUsed", ctypes.c_uint32),
        ("biClrImportant", ctypes.c_uint32),
    ]


def is_simulator_listening() -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.5)
        return s.connect_ex(("127.0.0.1", 1234)) == 0


def launch_simulator_on_desktop(sdk_bin: Path) -> PROCESS_INFORMATION:
    sim_exe = sdk_bin / "simulator.exe"
    si = STARTUPINFO()
    si.cb = ctypes.sizeof(STARTUPINFO)
    si.lpDesktop = "WinSta0\\Default"
    pi = PROCESS_INFORMATION()

    created = kernel32.CreateProcessW(
        str(sim_exe), None, None, None, False, 0, None, str(sdk_bin),
        ctypes.byref(si), ctypes.byref(pi),
    )
    if not created:
        err = kernel32.GetLastError()
        raise RuntimeError(f"Failed to start simulator: error {err}")

    for _ in range(10):
        time.sleep(0.5)
        if is_simulator_listening():
            break

    return pi


@app.command()
def build(
    device: str = typer.Option("venu445mm", help="Target device ID"),
    output: Path = typer.Option(Path("bin/garminmetar.prg"), help="Output PRG path"),
    jungle: Path = typer.Option(Path("monkey.jungle"), help="Path to monkey.jungle"),
    developer_key: Path = typer.Option(Path("developer_key"), help="Path to developer key"),
    sdk_path: Path | None = typer.Option(None, help="Custom path to Connect IQ SDK"),
) -> None:
    sdk_bin = find_sdk_bin(sdk_path)
    monkeyc = sdk_bin / "monkeyc.bat"
    output.parent.mkdir(parents=True, exist_ok=True)

    cmd = [
        str(monkeyc),
        "-f", str(jungle),
        "-o", str(output),
        "-y", str(developer_key),
        "-d", device,
    ]
    typer.echo(f"Building {output} for {device}...")
    subprocess.run(cmd, check=True)
    typer.echo("Build successful")


@app.command()
def test(
    device: str = typer.Option("venu445mm", help="Target device ID"),
    jungle: Path = typer.Option(Path("monkey.jungle"), help="Path to monkey.jungle"),
    developer_key: Path = typer.Option(Path("developer_key"), help="Path to developer key"),
    sdk_path: Path | None = typer.Option(None, help="Custom path to Connect IQ SDK"),
) -> None:
    sdk_bin = find_sdk_bin(sdk_path)
    monkeyc = sdk_bin / "monkeyc.bat"
    monkeydo = sdk_bin / "monkeydo.bat"
    test_prg = Path("bin/test.prg")
    test_prg.parent.mkdir(parents=True, exist_ok=True)

    typer.echo(f"Compiling unit tests for {device}...")
    build_cmd = [
        str(monkeyc),
        "-f", str(jungle),
        "-o", str(test_prg),
        "-y", str(developer_key),
        "-d", device,
        "-t",
    ]
    subprocess.run(build_cmd, check=True)

    sim_pi: PROCESS_INFORMATION | None = None
    if not is_simulator_listening():
        typer.echo("Starting Connect IQ simulator for test execution...")
        sim_pi = launch_simulator_on_desktop(sdk_bin)

    typer.echo("Running unit tests via monkeydo...")
    run_cmd = [str(monkeydo), str(test_prg), device, "/t"]
    res = subprocess.run(run_cmd)

    if sim_pi is not None:
        kernel32.CloseHandle(sim_pi.hProcess)
        kernel32.CloseHandle(sim_pi.hThread)

    if res.returncode != 0:
        raise typer.Exit(code=res.returncode)


@app.command()
def capture(
    device: str = typer.Option("venu445mm", help="Target device ID"),
    prg: Path = typer.Option(Path("bin/garminmetar.prg"), help="Path to compiled PRG"),
    output: Path = typer.Option(Path("media/watch_face.png"), help="Output image file path"),
    delay: float = typer.Option(5.0, help="Seconds to wait before capturing"),
    crop: bool = typer.Option(True, help="Crop to active watch display"),
    sdk_path: Path | None = typer.Option(None, help="Custom path to Connect IQ SDK"),
) -> None:
    sdk_bin = find_sdk_bin(sdk_path)
    shell_exe = sdk_bin / "shell.exe"
    monkeybrains_jar = sdk_bin / "monkeybrains.jar"

    if not prg.is_file():
        typer.echo(f"PRG not found at {prg}, building first...")
        build(device=device, output=prg, sdk_path=sdk_path)

    typer.echo("Starting Connect IQ simulator...")
    pi = launch_simulator_on_desktop(sdk_bin)
    sim_pid = pi.dwProcessId

    typer.echo(f"Deploying {prg} to {device} in simulator...")
    deploy_cmd = [
        "java",
        "-classpath", str(monkeybrains_jar),
        "com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux",
        "-f", str(prg.resolve()),
        "-d", device,
        "-s", str(shell_exe),
    ]
    monkey_proc = subprocess.Popen(deploy_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    def stream_logs() -> None:
        if monkey_proc.stdout:
            for line in monkey_proc.stdout:
                line_str = line.strip()
                if line_str:
                    typer.echo(f"  [CIQ] {line_str}")

    log_thread = threading.Thread(target=stream_logs, daemon=True)
    log_thread.start()

    typer.echo(f"Waiting {delay}s for app initialization and render...")
    time.sleep(delay)

    captured_img: Image.Image | None = None

    def capture_worker() -> None:
        nonlocal captured_img
        desktop_all = 0x01FF
        h_desk = user32.OpenDesktopW("Default", 0, False, desktop_all)
        if not h_desk:
            return
        user32.SetThreadDesktop(h_desk)

        target_hwnd: int | None = None
        target_rect = RECT()

        def enum_cb(hwnd: int, _: int) -> bool:
            nonlocal target_hwnd, target_rect
            if user32.IsWindowVisible(hwnd):
                pid = ctypes.c_ulong()
                user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
                if pid.value == sim_pid:
                    r = RECT()
                    user32.GetWindowRect(hwnd, ctypes.byref(r))
                    w = r.right - r.left
                    h = r.bottom - r.top
                    if w > 200 and h > 200:
                        target_hwnd = hwnd
                        target_rect = r
                        return False
            return True

        enum_proc = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)(enum_cb)
        user32.EnumDesktopWindows(h_desk, enum_proc, 0)

        if target_hwnd is not None:
            w = target_rect.right - target_rect.left
            h = target_rect.bottom - target_rect.top

            h_screen_dc = user32.GetDC(0)
            h_mem_dc = gdi32.CreateCompatibleDC(h_screen_dc)
            h_bitmap = gdi32.CreateCompatibleBitmap(h_screen_dc, w, h)
            gdi32.SelectObject(h_mem_dc, h_bitmap)

            pw_render_full_content = 2
            user32.PrintWindow(target_hwnd, h_mem_dc, pw_render_full_content)

            bmi = BITMAPINFOHEADER()
            bmi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
            bmi.biWidth = w
            bmi.biHeight = -h
            bmi.biPlanes = 1
            bmi.biBitCount = 32

            buf = (ctypes.c_char * (w * h * 4))()
            gdi32.GetDIBits(h_mem_dc, h_bitmap, 0, h, ctypes.byref(buf), ctypes.byref(bmi), 0)

            gdi32.DeleteObject(h_bitmap)
            gdi32.DeleteDC(h_mem_dc)
            user32.ReleaseDC(0, h_screen_dc)

            captured_img = Image.frombuffer("RGBA", (w, h), buf, "raw", "BGRA", 0, 1)

        user32.CloseDesktop(h_desk)

    worker_thread = threading.Thread(target=capture_worker)
    worker_thread.start()
    worker_thread.join()

    # Teardown processes
    monkey_proc.kill()
    kernel32.TerminateProcess(pi.hProcess, 0)
    kernel32.CloseHandle(pi.hProcess)
    kernel32.CloseHandle(pi.hThread)

    if captured_img is None:
        typer.echo("Failed to capture simulator window", err=True)
        raise typer.Exit(code=1)

    output.parent.mkdir(parents=True, exist_ok=True)
    if crop and captured_img.size == (666, 984):
        # Active round display for Venu 4 45mm simulator window
        final_img = captured_img.crop((108, 283, 558, 733))
    else:
        final_img = captured_img

    final_img.save(str(output))
    typer.echo(f"Screenshot saved to {output} (size: {final_img.size[0]}x{final_img.size[1]})")


if __name__ == "__main__":
    app()
