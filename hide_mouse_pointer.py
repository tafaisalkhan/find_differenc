import ctypes
import signal
import sys
import time


user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

SPI_SETCURSORS = 0x0057

SYSTEM_CURSOR_IDS = [
    32512,  # OCR_NORMAL
    32513,  # OCR_IBEAM
    32514,  # OCR_WAIT
    32515,  # OCR_CROSS
    32516,  # OCR_UP
    32640,  # OCR_SIZE
    32642,  # OCR_SIZENWSE
    32643,  # OCR_SIZENESW
    32644,  # OCR_SIZEWE
    32645,  # OCR_SIZENS
    32646,  # OCR_SIZEALL
    32648,  # OCR_NO
    32649,  # OCR_HAND
    32650,  # OCR_APPSTARTING
]


def create_blank_cursor():
    width = 32
    height = 32
    byte_count = width * height // 8
    and_mask = (ctypes.c_ubyte * byte_count)(*([0xFF] * byte_count))
    xor_mask = (ctypes.c_ubyte * byte_count)(*([0x00] * byte_count))
    return user32.CreateCursor(
        kernel32.GetModuleHandleW(None),
        0,
        0,
        width,
        height,
        and_mask,
        xor_mask,
    )


def hide_cursor() -> None:
    # This replaces common Windows system cursors with a transparent cursor.
    # Touchpad taps/clicks still work; only the pointer image is hidden.
    for cursor_id in SYSTEM_CURSOR_IDS:
        blank_cursor = create_blank_cursor()
        if not blank_cursor:
            raise ctypes.WinError()
        if not user32.SetSystemCursor(blank_cursor, cursor_id):
            raise ctypes.WinError()


def show_cursor() -> None:
    # Restores the active Windows cursor scheme.
    user32.SystemParametersInfoW(SPI_SETCURSORS, 0, None, 0)


def stop(_signum=None, _frame=None) -> None:
    show_cursor()
    print("\nMouse pointer restored.")
    sys.exit(0)


def main() -> None:
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    hide_cursor()
    print("Mouse pointer hidden system-wide. Touchpad taps still work.")
    print("Press Ctrl+C to restore it.")

    while True:
        time.sleep(1)


if __name__ == "__main__":
    main()
