#!/usr/bin/env bash
# Compile GMP, MPFR et Giac depuis leurs sources, puis libfikajiana_giac.so, pour une ABI Android.
# Usage : native/giac/construire.sh <arm64-v8a|x86_64>
set -euo pipefail

abi=$1
case "$abi" in
  arm64-v8a) hote=aarch64-linux-android ;;
  x86_64) hote=x86_64-linux-android ;;
  *) echo "ABI non prise en charge : $abi" >&2; exit 1 ;;
esac

ici=$(cd "$(dirname "$0")" && pwd)
ndk=${ANDROID_NDK:-$HOME/Android/Sdk/ndk/28.2.13676358}
api=24
outils="$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin"
sources="$ici/sources"
construit="$ici/construit/$abi"
prefixe="$construit/prefixe"
giac_commit=19a710aea9d528afa272ea582f3283f242e17af3
coeurs=$(nproc)

mkdir -p "$sources" "$prefixe"

telecharger() { # url fichier sha256
  [ -f "$sources/$2" ] || curl -fsSL -o "$sources/$2" "$1"
  echo "$3  $sources/$2" | sha256sum -c -
}

telecharger https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz gmp-6.3.0.tar.xz \
  a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898
telecharger https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz mpfr-4.2.1.tar.xz \
  277807353a6726978996945af13e52829e3abd7a9a5b7fb2793894e18f1fcbb2

if [ ! -d "$sources/giac" ]; then
  git clone --depth 1 https://github.com/geogebra/giac.git "$sources/giac"
fi
if [ "$(git -C "$sources/giac" rev-parse HEAD)" != "$giac_commit" ]; then
  echo "Giac n'est pas au commit attendu $giac_commit" >&2
  exit 1
fi

for correctif in "$ici"/correctifs/*.patch; do
  if git -C "$sources/giac" apply --check "$correctif" 2> /dev/null; then
    git -C "$sources/giac" apply "$correctif"
  fi
done

export CC="$outils/$hote$api-clang" CXX="$outils/$hote$api-clang++"
export AR="$outils/llvm-ar" RANLIB="$outils/llvm-ranlib" STRIP="$outils/llvm-strip"

if [ ! -f "$prefixe/lib/libgmp.a" ]; then
  rm -rf "$construit/gmp" && mkdir -p "$construit/gmp"
  tar -xf "$sources/gmp-6.3.0.tar.xz" -C "$construit/gmp" --strip-components=1
  (cd "$construit/gmp" && ./configure --host="$hote" --prefix="$prefixe" --disable-shared --with-pic \
    && make -j"$coeurs" && make install)
fi

if [ ! -f "$prefixe/lib/libmpfr.a" ]; then
  rm -rf "$construit/mpfr" && mkdir -p "$construit/mpfr"
  tar -xf "$sources/mpfr-4.2.1.tar.xz" -C "$construit/mpfr" --strip-components=1
  (cd "$construit/mpfr" && ./configure --host="$hote" --prefix="$prefixe" --with-gmp="$prefixe" --disable-shared --with-pic \
    && make -j"$coeurs" && make install)
fi

unset CC CXX AR RANLIB STRIP
cmake -S "$ici" -B "$construit/giac" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$ndk/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="$abi" -DANDROID_PLATFORM="android-$api" -DANDROID_STL=c++_static \
  -DCMAKE_BUILD_TYPE=Release -DPREFIXE="$prefixe" -DGIAC_SOURCES_DIR="$sources/giac"
cmake --build "$construit/giac" -j "$coeurs"

mkdir -p "$ici/construit/jniLibs/$abi"
cp "$construit/giac/libfikajiana_giac.so" "$ici/construit/jniLibs/$abi/"
ls -la "$ici/construit/jniLibs/$abi/"
