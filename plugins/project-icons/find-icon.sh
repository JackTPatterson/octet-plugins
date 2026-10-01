#!/bin/sh
# Prints the project's own icon, for the workspace in Octet's sidebar: a web
# app's favicon, or a mobile or Mac app's icon. Run in the workspace folder;
# prints a path inside it, or nothing.
root=${OCTET_REPO_ROOT:-$PWD}
cd "$root" 2>/dev/null || exit 0

first() {
  for path in "$@"; do
    if [ -f "$path" ]; then echo "$root/$path"; exit 0; fi
  done
}

# A file under the project, skipping what's built or installed.
search() {
  depth=$1
  shift
  find . -maxdepth "$depth" \( -name node_modules -o -name .git -o -name build -o -name dist -o -name .next \
    -o -name Pods -o -name DerivedData -o -name .build -o -name vendor -o -name .expo \) -prune -o "$@" -print 2>/dev/null
}

# 1. What the web page itself links: <link rel="icon" href="...">.
for page in index.html public/index.html src/index.html app/index.html; do
  [ -f "$page" ] || continue
  href=$(tr '\n' ' ' < "$page" | grep -oiE '<link[^>]+rel="?(shortcut )?icon"?[^>]*>' | head -n 1 \
    | grep -oiE 'href="[^"]+"' | head -n 1 | sed 's/^href="//; s/"$//; s/[?#].*//')
  case "$href" in ""|http*|data:*|//*) ;; *)
    href=${href#/}
    first "public/$href" "$(dirname "$page")/$href" "$href" "static/$href"
    ;;
  esac
done

# 2. Framework conventions.
first app/icon.svg app/icon.png app/favicon.ico src/app/icon.svg src/app/icon.png src/app/favicon.ico \
  public/favicon.svg public/favicon.png public/favicon.ico public/apple-touch-icon.png public/icon.svg public/icon.png \
  public/logo192.png public/icons/icon-512x512.png public/icons/icon-192x192.png public/android-chrome-512x512.png \
  static/favicon.svg static/favicon.png static/favicon.ico src/favicon.svg src/favicon.png src/favicon.ico \
  src/assets/favicon.svg src/assets/favicon.png assets/favicon.png assets/favicon.ico \
  favicon.svg favicon.png favicon.ico web/favicon.png

# 3. Expo and React Native: app.json's icon.
for config in app.json app.config.json; do
  [ -f "$config" ] || continue
  icon=$(grep -oE '"icon"[[:space:]]*:[[:space:]]*"[^"]+"' "$config" | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/; s#^\./##')
  [ -n "$icon" ] && first "$icon"
done
first assets/icon.png assets/images/icon.png assets/adaptive-icon.png

# 4. iOS and macOS: the largest image in the app icon set.
set_dir=$(search 6 -type d -name 'AppIcon.appiconset' | head -n 1)
if [ -n "$set_dir" ]; then
  largest='' size=0
  for image in "$set_dir"/*.png "$set_dir"/*.jpg "$set_dir"/*.jpeg; do
    [ -f "$image" ] || continue
    bytes=$(wc -c < "$image" | tr -d ' ')
    if [ "$bytes" -gt "$size" ]; then size=$bytes largest=$image; fi
  done
  [ -n "$largest" ] && first "${largest#./}"
fi

# 5. Android and Flutter: the launcher icon at the highest density.
for density in xxxhdpi xxhdpi xhdpi hdpi mdpi; do
  for base in app/src/main/res android/app/src/main/res; do
    first "$base/mipmap-$density/ic_launcher.png" "$base/mipmap-$density/ic_launcher_round.png" \
      "$base/mipmap-$density/ic_launcher.webp" "$base/mipmap-$density/ic_launcher_foreground.png"
  done
done
exit 0
