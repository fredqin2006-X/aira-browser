# Self-hosting guide

Self-hosting means running your own sync server. Once your phone and computer are paired with the same server, you can sync bookmarks, history, personalization and the novel bookshelf, and you can use page push and cross-device tabs.

It needs no Huawei account and no Aira Pro. One server serves one person: there is no sign-up, no password account and no membership. Each device pairs on its own, and a pairing code can be used only once. Disconnecting removes only that device's connection; it does not delete browsing data already on your phone or computer.

The server administrator can read the data that is synced to it. Do not expose this server to a network you do not trust.

## Before you start

- A computer or server that can run Docker.
- Aira on your phone.
- The Aira-sync extension in your desktop browser. Chrome, Edge and Firefox all work.
- If your phone and computer are on the same trusted local network, HTTP is fine. As soon as traffic leaves that network, use HTTPS.

## 1. Start the server

In the `services/personal-server` directory of this repository, run:

```bash
cp .env.example .env
docker compose up -d --build
docker compose exec aira-server cat /data/setup-code
```

The last command prints the one-time pairing code. It is meant for the first device only, and the server deletes it once a device has paired. If no device pairs within 24 hours, the code expires as well.

By default the server only listens on `127.0.0.1:8787` on the local machine. A browser on the computer running the server can reach it; your phone cannot.

## 2. Let your phone reach it

If you only connect the extension on the computer that runs the server, use:

```text
http://127.0.0.1:8787
```

If your phone should connect too, first make the server reachable from the phone.

On the same home network, open the port to the local network in `compose.yaml` and restart:

```yaml
ports:
  - "8787:8787"
```

```bash
docker compose up -d
```

On your phone, enter the computer's local network address, for example `http://192.168.1.20:8787`. Only do this on a network you trust. Never expose port `8787` directly to the internet.

To use it outside your home network, put a trusted HTTPS reverse proxy in front and write the public address into `.env`:

```dotenv
AIRA_PUBLIC_URL=https://sync.example.com
```

With Caddy it can look like this:

```caddyfile
sync.example.com {
  reverse_proxy 127.0.0.1:8787
}
```

The reverse proxy must keep the `Authorization` request header and allow a request body of at least 12 MiB. Do not use a self-signed certificate that neither your phone nor your computer trusts.

After the change, you can confirm on the computer that the service is still up:

```bash
curl --fail --silent http://127.0.0.1:8787/health
```

Your phone browser should also be able to open `/health` at the address you are going to enter.

## 3. Pair on your phone

1. Open Aira and go to "Settings" - "Sync", then choose "Self-hosting". You can also reach the same page from "Link with a computer".
2. For the server address, enter an address your phone can open. Do not add a path at the end.
3. For the one-time pairing code, enter the code printed in the previous step.
4. You can keep the default device name.
5. Tap "Connect and pair".

A pairing code is used only once. The device credentials are stored on this phone; your Huawei account token, membership and payment data are never sent to this server.

## 4. Install and pair on your computer

Copy the extension link for your browser and open it on the computer. The store listings belong to the Official distribution; the Community distribution is not listed in extension stores.

- [Chrome extension link](https://chromewebstore.google.com/detail/aira-focused-webdav-new-t/hgifgplkfbfmkogjdpcjkgbgkikcjpni?hl=en-US)
- [Edge extension link](https://microsoftedge.microsoft.com/addons/detail/afliopnmelmcajnmldmiklifmbchgfni)
- [Firefox extension link](https://addons.mozilla.org/en-US/firefox/addon/aira-focused-webdav-new-tab)

For the Community distribution, or when the store is not available, download the local package from GitHub Releases:

- [Download the Community package from GitHub Releases](https://github.com/mason173/aira-browser/releases)

After installing:

1. Click the Aira-sync icon in the browser toolbar.
2. Choose "Connect to self-hosting".
3. Enter the same server address as on your phone. When the computer running the server connects to itself, `http://127.0.0.1:8787` works.
4. Enter a one-time pairing code that has not been used yet and tap "Connect and use".

Once your phone has used the pairing code printed at startup, it cannot be given to the computer as well. Every device needs its own pairing code. New pairing codes are issued by a device that has already paired; they are valid for 10 minutes and can be used only once.

Right now the pairing pages on both the phone and the desktop extension only accept a pairing code; there is no "Generate pairing code" button yet. So connect the first device with the startup code, and do not enter an already used code for the next device.

## 5. Turn on cross-device linking

Once pairing is done, open Aira on your phone, go to "Settings" - "Link with a computer" and turn on "Link with a computer". Self-hosting does not depend on sign-in state or on Aira Pro.

Keep Aira-sync open on the computer. After that you can:

- See the ordinary web pages currently open on the computer in the phone's tab manager, or see the phone's tabs in the desktop extension.
- Push the current page from your phone to a paired computer.

Only devices that are online, or were online just now, are shown. Settings pages, the new tab page and extension pages do not appear in cross-device tabs.

## Troubleshooting

- Your phone cannot open the address: `127.0.0.1` means the phone itself, not the server. Use the computer's local network address, or its public HTTPS address.
- The pairing code is rejected: it was already used, it has expired, or copying added spaces or line breaks. Get a new code.
- "Not a compatible self-hosted server": the address does not point at this server, or the reverse proxy does not pass `/.well-known/aira` through unchanged.
- The computer connected but the phone did not: both must enter the same server, and each must be able to reach the address it was given. You cannot use a local address on one side and an unreachable address on the other.
- Sync is not a backup. The database on the server is your data, so keep a separate backup.
