---
status: accepted
supersedes: none
---

# Cross-Device Link Is a First-Level Settings Page, Not a Tutorial

Accepted 2026-09-19. The desktop-browser link (Aira-sync extension) was reachable only from one row inside 同步 that
opened a markdown tutorial. It becomes a first-level settings destination with a real page that reports state, jogs the
user into pairing, and hands every dependent capability to the owner that already implements it.

## Decision

One destination, `cross_device_link`, registered in the settings catalog beside `Aira Pro` and `同步`, and one
content component behind it. It embeds as a settings pane on the PC shell exactly like `同步`, and stays a routed page
on phone and touch two-pane where there is no pane. The page is deliberately a **read-only projection plus deep links**:

- `CrossDeviceLinkViewModel` builds the whole page state from facts: the bookmark and history switches come from
  `SyncExperienceCoordinator`, the online computers come from `CrossDeviceTabPresenceCoordinator`, and the desktop-link
  availability is the existing `aira_cloud` distribution capability. The page never activates sync, never toggles a
  provider, and never keeps its own copy of sync state — `SyncExperienceCoordinator` remains the single state-transition
  owner (ADR 0048), and the frozen Aira-sync contract is untouched.
- 数据同步 and 与电脑互联 are two channels with two owners, and the page keeps them apart. This page owns the
  与电脑互联 switch (tab handoff and page push) through `CrossDeviceTabPresenceCoordinator`, whose preference is scoped
  to the paired account or server instance; turning it off stops publishing, stops the heartbeat and withdraws this
  phone's snapshot without touching any sync state. Data sync is only a 同步设置 row that carries the sync owner's own
  goal label and deep-links into 同步设置. The page deliberately carries no second data-sync master switch: pausing
  bookmarks and history must not look like it also stopped devices from talking, and one switch that means one thing
  cannot be explained to a user twice. The per-capability rows are gone for the same reason: they reported the same
  on/off twice and could not be acted on.
- The data-sync master switch stays in 同步设置, where it already has a confirmation dialog, a progress dialog and the
  owner's failure handling. It is a pause, not an erase: `suspendExperience` keeps the user's content selection so
  resuming restores it, which is why the content switches stay editable while the master switch is off. They report
  已暂停 instead of 已开启 in that state, and the section says the choice applies once sync resumes, so the row is
  neither lying nor pretending to be disabled configuration.
- The device list always begins with this phone and always ends with 添加设备. This phone is the one device the page can
  never be wrong about (the user is holding it), so it is read from the presence owner's own installation record and
  rendered as a static row marked 当前设备; the computers follow, and 添加设备 — the QR pairing handshake — is appended
  last in every state so pairing is never hidden behind an empty list.
Amended 2026-09-30: the header is the orbit graphic below, not the phone-account-computer row. The graphic is a
fixed background: the list starts beneath it, and scrolling up covers the rings. The rings are neutral and quiet in both
themes, with no hue of their own. While the page is open the marks revolve around the logo on their own rings.
The inner ring is fastest and the outer ring is slowest. There is no entrance sweep; they start on the reviewed pose.
The top of the graphic fades into the live page background, so light, dark, and any other palette dissolve into their
own page color rather than a fixed wash. The center logo is smaller than the first reviewed size, and the list start
follows the higher center.
- The page opens on the orbit graphic, not a status block and not the old phone-account-computer row. Three full rings
  share the Aira logo as their center. The other browser marks sit on those rings. The lower half of each ring fades out
  instead of being clipped. The top fades into the page background of the active theme. Account identity is still the sync owner's own `resolveAiraHuaweiAccountIdentity`
  (`displayName`, `uid`, `photoUrl`), so the page does not keep a second copy of account state; it is no longer the
  header. A signed-out account still resolves to 未登录 rather than an invented name.
- The page is provider-aware, because the desktop link is not the same thing on every mode. Aira Cloud and a self-hosted
  server carry the whole link; WebDAV carries bookmarks only; Huawei Space has no desktop browser side at all. The active
  mode is read from the sync owner's own goal options, never guessed, and a mode that cannot carry everything the page
  needs says so in one notice line under the header instead of hiding a row.

Amended 2026-09-22: a signed-in account carries tab handoff and page push even when data sync is off or the active
provider is WebDAV or Huawei Space. The notice that those providers cannot carry the link remains only on a build that
cannot sign in. Personal Server is unchanged: it is still its own paired channel, and selecting it does not also open
the account channel.
- The page carries no self-built action bar: it reports state and offers real rows. 添加设备 is what the device list
  already ends with, and 同步设置 is what the sync row already opens, so a button would only repeat them.
- Every row jumps to the owner: both sync rows to 同步设置, 网页接力 to the existing help document (which already
  documents the menu 推送 action), and 跨设备标签页 to a sheet that mounts the existing
  `BrowserCrossDeviceTabsSheet`, so the cross-device tab list has exactly one implementation.
- The install-and-pair recipe is a second level, `CrossDeviceLinkSetupPage`, reached from one row. The overview answers
  "can this mode reach a desktop"; the recipe is only needed once, so it does not sit in front of a user who is already
  paired. On phone and touch two-pane that page takes the active mode from its route params; in the PC pane the same
  `CrossDeviceLinkSetupScreen` is embedded with the mode passed as a prop and the scaffold header hidden. Both paths
  derive the steps with a pure function, so the recipe loads no sync state of its own. A tapped install link opens the
  same way on both: on the routed page it goes back to the browser shell, and in the PC pane the settings center asks
  the shell to open it (`open_external_url`) because `router.back` cannot leave a native-route settings scene.
- The PC address bar also offers the same tab list directly: a 跨设备标签页 button sits between the account popover and
  the user-script button and opens `BrowserCrossDeviceTabsSheet` in a popup. Tapping a remote tab reuses the shell's URL
  intent (`open_external_url`), so the two entries share one implementation.
- On the PC shell the page keeps sync inside the settings workspace: 去开启同步 / 更换同步方式 selects the 同步
  destination instead of pushing the routed sync page, whose selection sheets are bottom sheets. The pane's own sheets
  (desktop login confirmation, device tabs) also present as centered dialogs there.
- 添加设备 starts the existing QR scanner with the existing `DesktopLoginConfirmSheetContent` confirmation. Pairing stays
  one-directional: the computer shows a login QR code and the phone scans it. There is still no server flow for the
  reverse, and this page does not invent one.
- 私有化部署 replaces the separate WebDAV row: both are the same "bring your own server" answer, the sync owner already
  exposes them as `webdav` and `self_hosted`, and the row opens the existing self-hosted configuration page rather than
  the sync list.

The markdown tutorial does not disappear; it is demoted to the page's 帮助 action, which keeps a document glyph rather
than the scaffold's default action icon. Icons reuse the settings icon-background token set, so the page reads like the
rest of settings instead of one flat color.

Extension install links get one catalog, `SyncDesktopExtensionCatalog`. Store entries are `copy_link` because a phone
cannot install a desktop extension, while the local package is `open_link` and opens the download page in Aira. The store
entries are Official-only; a Community build offers only the local package.

The local package page is locked. Its password lives in the same catalog entry, and opening it copies the password first
and then tells the user it is ready to paste, so the handoff is one tap: open the page, paste the password.

## Distribution And Privacy

The page is one source tree for both distributions and rewrites itself from the `aira_cloud` capability instead of having
a second page. An Official build can sign in, so its page keeps the account wording, the scan pairing, the store links
and 私有化部署 as the alternative. A Community build cannot sign in at all, so its page is a self-hosted-only story: it
never names Aira Cloud, its steps never mention an account login, its footer asks for 私有化部署 rather than "Aira 云或私有化
部署", its 私有化部署 row is presented as 推荐方式 instead of the escape hatch, and its primary action sends the user straight
at configuring their own server. The install list narrows to the local package the same way.

Entry is gated by the same optional-service check as 同步, so a basic service mode never reaches it.

## Considered Options

- Keep the tutorial and only move its entry. Rejected: the entry was never the whole problem; a document cannot report
  whether the computer is paired, nor open the pairing flow.
- Add the page as a second state owner beside the sync screen. Rejected: two owners would drift, and the sync contract
  guards forbid it.
- Build a dedicated device-and-tab list on this page. Rejected: `BrowserCrossDeviceTabsSheet` already renders exactly
  that from the presence owner, including the open-remote-tab action.
- Show 需 Pro on the rows. Rejected by product: the page reports on/off, and the Pro requirement is stated once in the
  section footer instead of on every row.

## Consequences

- The entry is one settings row with a connection-status value. On the PC shell it embeds in the detail pane
  (`twoPanePresentation: 'desktop_embedded'`, the same presentation as `同步`); on phone and touch two-pane it stays the
  routed page (`CrossDeviceLinkPage`). The embedded pane hosts the same `CrossDeviceLinkScreen`, with the scaffold title
  bar and back button hidden and `onExit` returning to the destination list.
- The page owns no timers and no persistence: it reloads on appear and on the existing `SyncSettingsRefreshSignal`, and
  reflects whatever the sync and presence owners report, including their own empty and error messages.
- Amended 2026-09-30: the first time this device opens the page, a lesson plays the two computer-link clips. On a
  phone it is the system's tallest bottom sheet, edge to edge, with the clip flush to the top. It does not turn the
  page into a tutorial. The first step's button is 下一个. Only the second step's primary button opens the existing
  互联教程 page. 不再提示, back, dragging the sheet down, and leaving the page close it without opening the recipe.
  A tap on the dimmed page does not. The lesson is spent once it is shown, in its own preferences store, and is not a
  fact of `CrossDeviceLinkViewModel`. Amended 2026-09-30: the clip and the copy scroll; the two actions are a footer
  pinned near the bottom of the sheet, so the buttons do not strand mid-screen when the sheet is taller than the
  content. Both steps share that footer.
- Amended 2026-09-30: the orbit is decoration, so it sits higher and the list starts over the logo center rather than
  under its lower edge, and the device list carries no 在线设备 heading of its own. The recipe page is an ordinary
  settings list: it owns one scroller, and its title bar binds that same scroller so the top gradient blur follows the
  recipe's own scroll.
- The device list stays ephemeral by construction: it shows only what the presence owner currently reports as online.

## Verification

Proportional evidence is a Community build, the Official build, the architecture guardrails, and
`scripts/check-aira-cross-device-link-contract.sh`, which pins the single state builder, the owner-sourced facts, the
read-only rule, the always-on rows, the routed destination registration, the PC-shell embedded pane, and the link
catalog. The pure state builder is
pinned by `AiraBrowser/entry/src/test/CrossDeviceLinkViewModel.test.ets`.
