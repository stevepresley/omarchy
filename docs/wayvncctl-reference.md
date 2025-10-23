# wayvncctl Commands Reference

**Last Updated**: 2025-10-23

This is a reference of wayvncctl commands for quick lookup. Do NOT ask users for help text - consult this document instead.

## Available Commands

- `attach <socket>` - Attach to a running wayland compositor
- `detach` - Detach from the wayland compositor
- `event-receive` - Register to begin receiving asynchronous events from wayvnc
- `client-list` - Return a list of all currently connected VNC sessions
- `client-disconnect <id>` - Disconnect a VNC session
- `output-list` - Return a list of all currently detected Wayland outputs
- `output-cycle` - Cycle the actively captured output to the next available output
- `output-set <output>` - Switch the actively captured output
- `version` - Query the version of the wayvnc process
- `wayvnc-exit` - Disconnect all clients and shut down wayvnc

## Common Usage

Check attached output:
```bash
wayvncctl output-list
```

Attach to a specific socket:
```bash
wayvncctl attach /run/user/1000/wayland-1
```

Detach from current display:
```bash
wayvncctl detach
```

Monitor client events:
```bash
wayvncctl --wait --reconnect --json event-receive
```

## Notes

- The `--socket` flag specifies the control socket path (defaults to `/tmp/wayvncctl-0`)
- The `--json` flag outputs events in JSON format
- The `--wait` flag makes wayvncctl wait if wayvnc isn't running
- The `--reconnect` flag auto-reconnects if wayvnc restarts
