"""A narrow, user-operated front end for Steam Frame's travel-mode property."""
import argparse
import importlib.util
import json
import queue
import threading
import time

PROPERTY = '/driver_cv/enableTravelMode'


class Backend:
    def __init__(self, client):
        self.client = client

    def read(self):
        value = self.client.evaluate(
            'SteamClient.OpenVR.PathProperties.GetBoolPathProperty(' + json.dumps(PROPERTY) + ')')
        if type(value) is not bool:
            raise RuntimeError('Travel Mode is unavailable from this SteamVR runtime.')
        return value

    def set(self, target):
        if type(target) is not bool:
            raise ValueError('On or Off is required.')
        if self.read() == target:
            return target
        self.client.evaluate(
            'SteamClient.OpenVR.PathProperties.SetBoolPathProperty(' + json.dumps(PROPERTY) +
            ', ' + json.dumps(target) + ')')
        for _ in range(12):
            actual = self.read()
            if actual == target:
                return actual
            time.sleep(0.15)
        raise RuntimeError('SteamVR did not confirm the requested setting. Refresh to check its state.')


class Controller:
    """Serialize reads/writes so repeated clicks cannot queue conflicting requests."""
    def __init__(self, backend):
        self.backend = backend
        self.busy = False
        self.value = None
        self.error = None
        self.results = queue.Queue()
        self.closed = False

    def request(self, target=None):
        if self.closed or self.busy:
            return False
        if target is not None and (type(target) is not bool or self.value is None):
            return False
        if target is not None and target == self.value:
            return False
        self.busy = True
        self.error = None
        def work():
            try:
                value = self.backend.read() if target is None else self.backend.set(target)
                if type(value) is not bool:
                    raise RuntimeError('Travel Mode status is unavailable.')
                self.results.put((value, None))
            except Exception as error:
                message = str(error) if isinstance(error, RuntimeError) else 'Cannot reach SteamVR. Try Refresh when it is available.'
                self.results.put((None, message))
        threading.Thread(target=work, daemon=True).start()
        return True

    def collect(self):
        try:
            self.value, self.error = self.results.get_nowait()
        except queue.Empty:
            return False
        self.busy = False
        return True

    def close(self):
        self.closed = True


class Window:
    def __init__(self, root, backend, fixture=False):
        import tkinter as tk
        self.root = root
        self.controller = Controller(backend)
        self.closed = False
        self.next_refresh = time.monotonic() + 2
        root.title('Travel Mode' + (' — TEST FIXTURE' if fixture else ''))
        root.geometry('1000x650')
        root.minsize(900, 610)
        root.configure(bg='#111827')
        panel = tk.Frame(root, bg='#111827', padx=46, pady=32)
        panel.pack(fill='both', expand=True)
        tk.Label(panel, text='TRAVEL MODE', font=('DejaVu Sans', 26, 'bold'), fg='#f9fafb', bg='#111827').pack(anchor='w')
        tk.Label(panel, text='Experimental · Remain seated', font=('DejaVu Sans', 17), fg='#fbbf24', bg='#111827').pack(anchor='w', pady=(10, 16))
        self.status = tk.Label(panel, text='CHECKING…', font=('DejaVu Sans', 36, 'bold'), fg='#d1d5db', bg='#1f2937', pady=20)
        self.status.pack(fill='x')
        self.detail = tk.Label(panel, text='Reading the current SteamVR setting.', font=('DejaVu Sans', 15), fg='#d1d5db', bg='#111827', wraplength=890, justify='left', height=3)
        self.detail.pack(fill='x', pady=8)
        row = tk.Frame(panel, bg='#111827')
        row.pack(fill='x', pady=(0, 18))
        self.on = tk.Button(row, text='Turn On', command=lambda: self.request(True), font=('DejaVu Sans', 23, 'bold'), bg='#2563eb', fg='white', activebackground='#1d4ed8', activeforeground='white', disabledforeground='#94a3b8', height=2, relief='flat', takefocus=True)
        self.off = tk.Button(row, text='Turn Off', command=lambda: self.request(False), font=('DejaVu Sans', 23, 'bold'), bg='#374151', fg='white', activebackground='#4b5563', activeforeground='white', disabledforeground='#94a3b8', height=2, relief='flat', takefocus=True)
        self.on.pack(side='left', fill='x', expand=True, padx=(0, 9))
        self.off.pack(side='left', fill='x', expand=True, padx=(9, 0))
        tk.Label(panel, text='Changing this setting may briefly shift your view.\nThe setting may reset between sessions. Closing this window leaves it as it is.', font=('DejaVu Sans', 14), fg='#d1d5db', bg='#111827', justify='left', wraplength=890).pack(anchor='w')
        footer = tk.Frame(panel, bg='#111827')
        footer.pack(fill='x', pady=(22, 0))
        self.refresh = tk.Button(footer, text='Refresh status', command=self.request, font=('DejaVu Sans', 16), padx=22, pady=12)
        self.refresh.pack(side='left')
        tk.Button(footer, text='Close', command=self.close, font=('DejaVu Sans', 16), padx=32, pady=12).pack(side='right')
        root.protocol('WM_DELETE_WINDOW', self.close)
        root.bind('<Escape>', lambda _: self.close())
        self.request()
        root.after(80, self.tick)

    def request(self, target=None):
        if self.controller.request(target):
            self.render()

    def render(self):
        c = self.controller
        if c.busy:
            self.status.configure(text='CHECKING…' if c.value is None else 'PLEASE WAIT…', fg='#d1d5db')
            self.detail.configure(text='Waiting for SteamVR readback.')
        elif c.error:
            self.status.configure(text='UNAVAILABLE', fg='#fbbf24')
            self.detail.configure(text=c.error)
        else:
            self.status.configure(text='ON' if c.value else 'OFF', fg='#93c5fd' if c.value else '#d1d5db')
            self.detail.configure(text='Confirmed by SteamVR · status refreshes automatically')
        self.on.configure(state='normal' if not c.busy and c.value is False else 'disabled')
        self.off.configure(state='normal' if not c.busy and c.value is True else 'disabled')
        self.refresh.configure(state='disabled' if c.busy else 'normal')

    def tick(self):
        if self.closed:
            return
        if self.controller.collect():
            self.render()
            self.next_refresh = time.monotonic() + 3
        if not self.controller.busy and time.monotonic() >= self.next_refresh:
            self.request()
        self.root.after(80, self.tick)

    def close(self):
        self.closed = True
        self.controller.close()
        self.root.destroy()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--client-source', required=True)
    parser.add_argument('--status', action='store_true', help='Read status without opening a window; never writes.')
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('comet_steam_client', args.client_source)
    client_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(client_module)
    backend = Backend(client_module.Steam())
    if args.status:
        print(json.dumps({'travelMode': backend.read()}))
        return
    import tkinter as tk
    root = tk.Tk()
    Window(root, backend)
    root.mainloop()


if __name__ == '__main__':
    main()
