# /// script
# dependencies = [
#   "pillow>=10.0.0",
#   "typer>=0.12.0",
# ]
# ///
import ctypes
import os
import socket
import struct
import subprocess
import threading
import time
from pathlib import Path
from typing import Annotated
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


def encode_ciq_settings(settings: dict) -> bytes:
    """Encode app settings into Garmin Connect IQ binary .SET format."""
    body = bytearray()
    entries = []
    for k, v in settings.items():
        k_offset = len(body)
        k_bytes = k.encode("ascii") + b"\x00"
        body += struct.pack(">H", len(k_bytes)) + k_bytes

        if isinstance(v, str):
            v_offset = len(body)
            v_bytes = v.encode("ascii") + b"\x00"
            body += struct.pack(">H", len(v_bytes)) + v_bytes
            entries.append((3, k_offset, 3, v_offset))
        elif isinstance(v, int):
            entries.append((3, k_offset, 1, v))
        else:
            raise ValueError(f"Unsupported type: {type(v)}")

    trailer_body = bytearray()
    trailer_body += b"\x0b"  # version
    trailer_body += struct.pack(">I", len(entries))
    for k_type, k_off, v_type, v_val in entries:
        trailer_body += struct.pack(">BI", k_type, k_off)
        trailer_body += struct.pack(">BI", v_type, v_val)

    trailer = b"\xda\x7a\xda\x7a" + struct.pack(">I", len(trailer_body)) + trailer_body
    header = b"\xab\xcd\xab\xcd" + struct.pack(">I", len(body))
    return bytes(header + body + trailer)


def write_simulator_settings(
    token: str = "MOCK_VFR",
    station: str = "EGLL",
    station_list: str = "EGWU,EGLL,EGUB,EGVO,KJFK,KLAX",
    auto_exit_seconds: int = 300,
    target_name: str = "TEST.SET",
    simulated_gps: str = "",
    nearby_count: int = 5,
) -> Path:
    """Write mock settings to Connect IQ simulator settings directory."""
    settings = {
        "StationList": station_list,
        "AutoExitSeconds": auto_exit_seconds,
        "AvwxToken": token,
        "TargetStation": station,
        "SimulatedGps": simulated_gps,
        "NearbyCount": nearby_count,
    }
    encoded = encode_ciq_settings(settings)
    temp_dir = Path(os.environ.get("TEMP", os.environ.get("TMP", "C:/Temp")))
    settings_dir = temp_dir / "com.garmin.connectiq" / "GARMIN" / "APPS" / "SETTINGS"
    settings_dir.mkdir(parents=True, exist_ok=True)
    target = settings_dir / target_name
    target.write_bytes(encoded)
    return target


def load_env_file(env_path: Path) -> dict[str, str]:
    """Parse key=value pairs from a .env file."""
    if not env_path.is_file():
        return {}
    env_vars: dict[str, str] = {}
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            key, val = line.split("=", 1)
            env_vars[key.strip()] = val.strip().strip("'\"")
    return env_vars


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
    device: Annotated[str, typer.Option(help="Target device ID")] = "venu445mm",
    output: Annotated[Path, typer.Option(help="Output PRG path")] = Path("bin/garminmetar.prg"),
    jungle: Annotated[Path, typer.Option(help="Path to monkey.jungle")] = Path("monkey.jungle"),
    developer_key: Annotated[Path, typer.Option(help="Path to developer key")] = Path("developer_key"),
    sdk_path: Annotated[Path | None, typer.Option(help="Custom path to Connect IQ SDK")] = None,
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
    device: Annotated[str, typer.Option(help="Target device ID")] = "venu445mm",
    jungle: Annotated[Path, typer.Option(help="Path to monkey.jungle")] = Path("monkey.jungle"),
    developer_key: Annotated[Path, typer.Option(help="Path to developer key")] = Path("developer_key"),
    sdk_path: Annotated[Path | None, typer.Option(help="Custom path to Connect IQ SDK")] = None,
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
    device: Annotated[str, typer.Option(help="Target device ID")] = "venu445mm",
    prg: Annotated[Path | None, typer.Option(help="Path to compiled PRG (builds automatically if not specified)")] = None,
    output: Annotated[Path, typer.Option(help="Output image file path")] = Path("media/watch_face.png"),
    delay: Annotated[float, typer.Option(help="Seconds to wait before capturing")] = 3.5,
    crop: Annotated[bool, typer.Option(help="Crop to active watch display (defaults to full bezel window)")] = False,
    mock: Annotated[str, typer.Option(help="Mock fixture (MOCK_VFR, MOCK_IFR_LONG, MOCK_MVFR, MOCK_TAF, MOCK_AUTH_ERROR, or empty for live API)")] = "MOCK_VFR",
    station: Annotated[str, typer.Option(help="Station code for mock/test")] = "EGLL",
    sdk_path: Annotated[Path | None, typer.Option(help="Custom path to Connect IQ SDK")] = None,
) -> None:
    sdk_bin = find_sdk_bin(sdk_path)
    shell_exe = sdk_bin / "shell.exe"
    monkeybrains_jar = sdk_bin / "monkeybrains.jar"

    target_prg = prg
    if target_prg is None or not target_prg.is_file():
        target_prg = Path(f"bin/{device}.prg")
        typer.echo(f"Building {target_prg} for {device}...")
        build(device=device, output=target_prg, sdk_path=sdk_path)

    if mock:
        typer.echo(f"Injecting mock settings (token={mock}, station={station})...")
        write_simulator_settings(token=mock, station=station)

    typer.echo("Starting Connect IQ simulator...")
    pi = launch_simulator_on_desktop(sdk_bin)
    sim_pid = pi.dwProcessId

    typer.echo(f"Deploying {target_prg} to {device} in simulator...")
    deploy_cmd = [
        "java",
        "-classpath", str(monkeybrains_jar),
        "com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux",
        "-f", str(target_prg.resolve()),
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
        final_img = captured_img.crop((108, 283, 558, 733))
    else:
        final_img = captured_img

    final_img.save(str(output))
    typer.echo(f"Screenshot saved to {output} (size: {final_img.size[0]}x{final_img.size[1]})")


@app.command()
def matrix(
    output_dir: Annotated[Path, typer.Option(help="Output directory for matrix screenshots")] = Path("media/matrix"),
    sdk_path: Annotated[Path | None, typer.Option(help="Custom path to Connect IQ SDK")] = None,
) -> None:
    """Run visual test matrix across all key device archetypes and mock scenarios."""
    test_devices = [
        ("instinct3solar45mm", "Semi-Octagon (Instinct 3 Solar)"),
        ("venu445mm", "Round AMOLED (Venu 4 45mm)"),
        ("fenix7", "Round MIP (Fenix 7)"),
        ("venusq2", "Rectangle AMOLED Watch (Venu Sq 2)"),
        ("edge840", "Rectangle Bike Computer (Edge 840)"),
    ]

    mock_scenarios = [
        ("MOCK_VFR", "EGLL", "Standard VFR"),
        ("MOCK_IFR_LONG", "KJFK", "Long IFR with Remarks"),
    ]

    output_dir.mkdir(parents=True, exist_ok=True)
    results = []

    for dev_id, dev_desc in test_devices:
        prg_path = Path(f"bin/{dev_id}.prg")
        build(device=dev_id, output=prg_path, sdk_path=sdk_path)

        for mock_id, station, mock_desc in mock_scenarios:
            img_path = output_dir / f"{dev_id}_{mock_id.lower()}.png"
            typer.echo(f"\n--- Testing {dev_desc} with {mock_desc} ---")
            capture(
                device=dev_id,
                prg=prg_path,
                output=img_path,
                delay=3.0,
                crop=False,
                mock=mock_id,
                station=station,
                sdk_path=sdk_path,
            )
            results.append((dev_id, dev_desc, mock_id, mock_desc, img_path))

    typer.echo(f"\nMatrix capture complete! {len(results)} screenshots generated in {output_dir}")


@app.command("sync-settings")
def sync_settings(
    env_file: Annotated[Path, typer.Option(help="Path to .env file")] = Path(".env"),
    app_name: Annotated[str, typer.Option(help="Target app settings prefix")] = "GARMINMETAR",
) -> None:
    """Sync .env variables to Connect IQ simulator binary settings."""
    env_vars = load_env_file(env_file)
    token = env_vars.get("AVWX_TOKEN") or os.environ.get("AVWX_TOKEN", "YOUR_TOKEN_HERE")
    station = env_vars.get("TARGET_STATION") or os.environ.get("TARGET_STATION", "EGWU")
    station_list = env_vars.get("STATION_LIST") or os.environ.get("STATION_LIST", "EGWU,EGLL,EGUB,EGVO,KJFK,KLAX")
    raw_auto_exit = env_vars.get("AUTO_EXIT_SECONDS") or os.environ.get("AUTO_EXIT_SECONDS", "30")
    try:
        auto_exit = int(raw_auto_exit)
    except ValueError:
        auto_exit = 30
    raw_nearby_count = env_vars.get("NEARBY_COUNT") or os.environ.get("NEARBY_COUNT", "5")
    try:
        nearby_count = int(raw_nearby_count)
    except ValueError:
        nearby_count = 5
    sim_gps = env_vars.get("SIMULATED_GPS") or os.environ.get("SIMULATED_GPS", "")

    write_simulator_settings(
        token=token,
        station=station,
        station_list=station_list,
        auto_exit_seconds=auto_exit,
        target_name=f"{app_name}.SET",
        simulated_gps=sim_gps,
        nearby_count=nearby_count,
    )
    write_simulator_settings(
        token=token,
        station=station,
        station_list=station_list,
        auto_exit_seconds=auto_exit,
        target_name="TEST.SET",
        simulated_gps=sim_gps,
        nearby_count=nearby_count,
    )
    source_desc = f"from {env_file}" if env_file.is_file() else "using defaults (no .env found)"
    masked_token = (token[:4] + "..." + token[-4:]) if len(token) > 8 and token != "YOUR_TOKEN_HERE" else token
    gps_info = f", GPS: {sim_gps}" if sim_gps else ""
    typer.echo(f"Synced simulator settings {source_desc} -> {app_name}.SET & TEST.SET [Station: {station}, Token: {masked_token}{gps_info}]")


if __name__ == "__main__":
    app()
