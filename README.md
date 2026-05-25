# Noctalia SDDM Theme

A cozy, elegant login theme for **SDDM**, designed to complement the **Noctalia Shell** experience. Features dynamic color syncing from Noctalia's wallpaper-based theming engine, animated blur on password input, and smart avatar detection.

![Noctalia SDDM Preview](Assets/preview.png)

## Features

- **Dynamic Color Sync** — Colors update automatically from Noctalia's theming engine via a post-hook.
- **Wallpaper Sync** — Login screen wallpaper mirrors your current desktop wallpaper.
- **Avatar Sync** — User avatar is pulled from Noctalia settings with multiple fallbacks.
- **Animated Focus Blur** — Background blurs smoothly when you start typing your password.
- **Responsive Scaling** — Adapts to 1080p, 1440p, and 4K resolutions (scale clamp 0.75–2.0).
- **Smart Avatar Handling** — Falls back through AccountsService, `~/.face`, SDDM faces, and theme logo.
- **Session Management** — Switch between Wayland/X11 sessions from the login screen.
- **Integrated Power Controls** — Suspend, Reboot, and Shutdown directly from the login screen.
- **Customizable** — Colors, blur, and avatar path configurable via `theme.conf`.

## Requirements

- `sddm-greeter-qt6`
- `qt6-5compat` (provides `Qt5Compat.GraphicalEffects`)
- `qt6-declarative`
- [Noctalia Shell](https://github.com/noctalia) (for color/wallpaper/avatar sync)

## Installation

### 1. Clone the repository

```sh
git clone -b main https://github.com/blackcityskyline/noctalia-sddm.git
```

### 2. Install the theme

Copy to your local SDDM themes directory (no root required):

```sh
mkdir -p ~/.local/share/sddm/themes/
cp -r noctalia-sddm ~/.local/share/sddm/themes/
```

### 3. Configure SDDM

```sh
sudo nano /etc/sddm.conf
```

```ini
[Theme]
Current=noctalia-sddm
ThemeDir=/home/YOUR_USERNAME/.local/share/sddm/themes
```

### 4. Restart SDDM

```sh
sudo systemctl restart sddm
```

## Noctalia Integration (optional)

For automatic color, wallpaper, and avatar sync with Noctalia Shell:

### 1. Add the sync script

Copy `noctalia-sddm-colors` to your PATH and make it executable:

```sh
cp noctalia-sddm-colors ~/bin/noctalia-sddm-colors
chmod +x ~/bin/noctalia-sddm-colors
```

### 2. Add the template

Copy the template to Noctalia's templates directory:

```sh
cp sddm-theme.conf.template ~/.config/noctalia/templates/
```

Add to `~/.config/noctalia/user-templates.toml`:

```toml
[templates.sddm]
input_path = "~/.config/noctalia/templates/sddm-theme.conf.template"
output_path = "~/.cache/noctalia/sddm-theme.conf"
```

### 3. Add the hook

In Noctalia Shell settings → Hooks → **Colors generated**:

```
~/bin/noctalia-sddm-colors noctalia-sddm
```

Now every time you change your wallpaper or color scheme, the SDDM theme updates automatically.

## Configuration

`theme.conf` supports the following options:

```ini
[General]
# Path to background image (overridden by sync script if using Noctalia)
background=Assets/background.png

# Static background blur radius (0 = off)
blurRadius=0

# Blur radius when typing password (0 = off)
focusBlurRadius=32

# Avatar path (synced automatically by noctalia-sddm-colors)
avatarPath=/home/user/Pictures/avatar.jpg

# Color palette (synced automatically from Noctalia)
mPrimary=#c7a1d8
mOnPrimary=#1a151f
mSecondary=#a984c4
mOnSecondary=#f3edf7
mTertiary=#e0b7c9
mOnTertiary=#20161f
mError=#e9899d
mOnError=#1e1418
mSurface=#1c1822
mOnSurface=#e9e4f0
mSurfaceVariant=#262130
mOnSurfaceVariant=#a79ab0
mOutline=#342c42
mShadow=#120f18
mHover=#e0b7c9
mOnHover=#20161f
```

## Testing

Test the theme without logging out:

```sh
sddm-greeter-qt6 --test-mode --theme ~/.local/share/sddm/themes/noctalia-sddm/
```

> If you see "module is not installed" errors, install `qt6-5compat`.

## Credits

- Designed for **Noctalia Shell**.
- Original theme by [mahaveergurjar](https://github.com/mahaveergurjar).
- Noctalia integration, UI fixes, and sync tooling by [blackcityskyline](https://github.com/blackcityskyline).
