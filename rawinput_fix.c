/*
 * version.dll proxy for GTA5_Enhanced.exe under Wine/Proton.
 *
 * The game registers keyboard raw input (usage page 1, usage 6) with
 * RIDEV_INPUTSINK and a hwndTarget that is not a valid window in Wine, so every
 * keyboard WM_INPUT is dropped. This DLL watches the registration and, when the
 * target is not a window, registers the keyboard again with no target, which
 * makes Wine deliver WM_INPUT to the focus window (same as the mouse).
 *
 * It also clears a Super key that Wine still thinks is held (see below).
 *
 * The version.dll exports are forwarded to kernelbase in rawinput_fix.def.
 */
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

static FILE *log_file;

static void log_line(const char *fmt, ...)
{
    va_list args;
    SYSTEMTIME t;

    if (!log_file) return;
    GetLocalTime(&t);
    fprintf(log_file, "[%02u:%02u:%02u.%03u] ", t.wHour, t.wMinute, t.wSecond, t.wMilliseconds);
    va_start(args, fmt);
    vfprintf(log_file, fmt, args);
    va_end(args);
    fputc('\n', log_file);
    fflush(log_file);
}

static void fix_keyboard_target(void)
{
    RAWINPUTDEVICE devices[16];
    UINT count = ARRAYSIZE(devices);
    UINT i, n;

    n = GetRegisteredRawInputDevices(devices, &count, sizeof(RAWINPUTDEVICE));
    if (n == (UINT)-1) return;

    for (i = 0; i < n; i++)
    {
        RAWINPUTDEVICE fixed;

        if (devices[i].usUsagePage != 0x01 || devices[i].usUsage != 0x06) continue;
        if (!devices[i].hwndTarget || IsWindow(devices[i].hwndTarget)) continue;

        fixed = devices[i];
        fixed.hwndTarget = NULL;
        fixed.dwFlags &= ~(RIDEV_INPUTSINK | RIDEV_EXINPUTSINK);

        if (RegisterRawInputDevices(&fixed, 1, sizeof(fixed)))
            log_line("keyboard target %p is not a window, flags 0x%lx -> re-registered with no target, flags 0x%lx",
                     devices[i].hwndTarget, devices[i].dwFlags, fixed.dwFlags);
        else
            log_line("re-register failed for target %p, error %lu", devices[i].hwndTarget, GetLastError());
    }
}

/*
 * Stuck Super key: when the compositor takes keyboard focus from XWayland (Super+N,
 * Super+drag), XWayland releases the held keys without sending KeyRelease to X
 * clients. Wine only resyncs on an X FocusIn, which does not always happen, so
 * VK_LWIN stays down for the game thread and FiveM's console ignores Super+Enter.
 * Sending a key up with SendInput did not change what the thread reads. Super is
 * never used in game, so before each key message is dispatched the thread's own
 * key state (what GetKeyState returns) is written with Super up.
 */
static HWND game_window;
static BOOL debug_enabled;

static void clear_stuck_super(void)
{
    BYTE state[256];

    if (GetKeyState(VK_LWIN) >= 0 && GetKeyState(VK_RWIN) >= 0) return;
    if (!GetKeyboardState(state)) return;
    state[VK_LWIN] = state[VK_RWIN] = 0;
    if (SetKeyboardState(state))
        log_line("cleared stuck super");
    else
        log_line("failed to clear stuck super, error %lu", GetLastError());
}

/* Debug only (RAWINPUT_FIX_DEBUG=1): Windows-side focus and modifier state on Enter/Ctrl/A. */
static void window_desc(HWND hwnd, char *buf, size_t size)
{
    WCHAR class_name[64] = {0};
    DWORD pid = 0;

    if (!hwnd) { snprintf(buf, size, "(null)"); return; }
    GetClassNameW(hwnd, class_name, ARRAYSIZE(class_name));
    GetWindowThreadProcessId(hwnd, &pid);
    snprintf(buf, size, "%p \"%ls\" pid %lu", hwnd, class_name, pid);
}

/* Runs on the game thread when a message is removed from its queue, before dispatch. */
static LRESULT CALLBACK getmessage_hook(int code, WPARAM wparam, LPARAM lparam)
{
    MSG *msg = (MSG *)lparam;

    if (code == HC_ACTION && wparam == PM_REMOVE &&
        (msg->message == WM_KEYDOWN || msg->message == WM_SYSKEYDOWN) &&
        msg->wParam != VK_LWIN && msg->wParam != VK_RWIN)
    {
        clear_stuck_super();

        if (debug_enabled && (msg->wParam == VK_RETURN || msg->wParam == VK_CONTROL || msg->wParam == 'A'))
        {
            char fg[160], active[160], focus[160];

            window_desc(GetForegroundWindow(), fg, sizeof(fg));
            window_desc(GetActiveWindow(), active, sizeof(active));
            window_desc(GetFocus(), focus, sizeof(focus));
            log_line("keydown 0x%02x to %p | foreground %s | active %s | focus %s"
                     " | held: lwin %d rwin %d alt %d ctrl %d shift %d",
                     (UINT)msg->wParam, msg->hwnd, fg, active, focus,
                     GetKeyState(VK_LWIN) < 0, GetKeyState(VK_RWIN) < 0, GetKeyState(VK_MENU) < 0,
                     GetKeyState(VK_CONTROL) < 0, GetKeyState(VK_SHIFT) < 0);
        }
    }
    return CallNextHookEx(NULL, code, wparam, lparam);
}

static void hook_game_window(void)
{
    HWND hwnd = FindWindowW(L"sgaWindow", NULL);
    DWORD pid = 0, tid;

    if (!hwnd || hwnd == game_window) return;
    tid = GetWindowThreadProcessId(hwnd, &pid);
    if (pid != GetCurrentProcessId()) return;
    game_window = hwnd;
    if (!SetWindowsHookExW(WH_GETMESSAGE, getmessage_hook, NULL, tid))
        log_line("key hook failed, error %lu", GetLastError());
    else
        log_line("hooked game window %p thread %lu", hwnd, tid);
}

static DWORD WINAPI watch_thread(void *arg)
{
    log_line("watching keyboard raw input registration%s", debug_enabled ? " (debug on)" : "");
    for (;;)
    {
        fix_keyboard_target();
        hook_game_window();
        Sleep(100);
    }
    return 0;
}

static BOOL is_game_process(void)
{
    WCHAR path[MAX_PATH];
    const WCHAR *name;

    if (!GetModuleFileNameW(NULL, path, MAX_PATH)) return FALSE;
    name = wcsrchr(path, L'\\');
    name = name ? name + 1 : path;
    return !_wcsicmp(name, L"GTA5_Enhanced.exe");
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, void *reserved)
{
    if (reason != DLL_PROCESS_ATTACH) return TRUE;

    DisableThreadLibraryCalls(instance);
    if (!is_game_process()) return TRUE;

    debug_enabled = GetEnvironmentVariableW(L"RAWINPUT_FIX_DEBUG", NULL, 0) > 0;
    log_file = _wfopen(L"C:\\users\\steamuser\\rawinput-fix.log", L"a");
    log_line("loaded in GTA5_Enhanced.exe (pid %lu)", GetCurrentProcessId());
    CloseHandle(CreateThread(NULL, 0, watch_thread, NULL, 0, NULL));
    return TRUE;
}

/* version.dll exports that kernelbase does not have. */
BOOL WINAPI GetFileVersionInfoByHandle(DWORD flags, HANDLE file, void **data, DWORD *size)
{
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    return FALSE;
}

DWORD WINAPI VerInstallFileA(DWORD flags, LPSTR src_name, LPSTR dest_name, LPSTR src_dir,
                             LPSTR dest_dir, LPSTR cur_dir, LPSTR tmp_name, PUINT tmp_len)
{
    return VIF_CANNOTREADSRC;
}

DWORD WINAPI VerInstallFileW(DWORD flags, LPWSTR src_name, LPWSTR dest_name, LPWSTR src_dir,
                             LPWSTR dest_dir, LPWSTR cur_dir, LPWSTR tmp_name, PUINT tmp_len)
{
    return VIF_CANNOTREADSRC;
}
