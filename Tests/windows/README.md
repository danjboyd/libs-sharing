# Windows hand checks

`Tests/gui/NSSharingService/rclone.m` fakes rclone with a `/bin/sh` script,
so it runs on Linux and macOS only. On Windows the rclone service is checked
by hand with `fake-rclone.c`: a stand-in `rclone.exe` with one fake OneDrive
remote and no network. It logs every call, with the `RCLONE_*` environment,
to `rclone-calls.log` beside itself.

| Command | Stand-in's answer |
|---|---|
| `listremotes --long` | `fakedrive: onedrive` |
| `lsf …` | exit 3 (the folder isn't there yet) |
| `copyto …` | JSON stats on stderr once a second for `FAKE_RCLONE_SECONDS` (8) |
| `link …` | `https://example.com/s/fake-share-link` |
| `deletefile …` | exit 0 |

Build it in MSYS2 CLANG64:

```sh
clang -O1 -static fake-rclone.c -o rclone.exe
```

Then, with a private `RCLONE_CONFIG`, put it on `Path`, or in
`%USERPROFILE%\scoop\shims`, `%ProgramData%\chocolatey\bin` or
`%LOCALAPPDATA%\Microsoft\WinGet\Links`. Start the app, Share with the
library's sheet (Windows Server, where the system share UI isn't there), and
choose "fakedrive". What to see:

- The progress panel advances.
- The notice puts the link on the clipboard and says who can open it.
- Cancel (try `FAKE_RCLONE_SECONDS=60`) stops rclone and runs `deletefile`.
- `rclone-calls.log` shows `RCLONE_CONFIG` and `RCLONE_ASK_PASSWORD=false` on every call.

Checked this way on Windows Server 2022 for ObjcMarkdown #198 (2026-10-16).
