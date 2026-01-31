# https://www.nowcoder.com/discuss/353147264694689792


yum install -y \
which flex bison gperf clang clang-devel \
mesa-libGLU libXrender libXi libxkbcommon libxkbcommon-x11 libpng llvm fontconfig \
sqlite mesa-libEGL python unixODBC nodejs \
fontconfig-devel libX11 libX11-devel libxcb-devel freetype freetype-devel \
mesa-libGL-devel mesa-libEGL-devel libglvnd-devel \
xcb-util-devel xcb-util-wm-devel xcb-util-image-devel xcb-util-keysyms-devel \
xcb-util-renderutil-devel libxkbcommon-devel libxkbcommon-x11-devel \
libXrandr-devel libXcursor-devel libXi-devel libXinerama-devel libXfixes-devel \
libXrender-devel libXtst-devel libXdamage-devel libXScrnSaver-devel \
libXcomposite-devel libXau-devel libXdmcp-devel \
libtool gcc gcc-c++ gcc-gfortran \
gdb cmake make gzip tar git \
--setopt=install_weak_deps=False --setopt=tsflags=nodocs

echo "==================================================================================="
echo "qt 动态编译环境依赖安装完成。。。。。。"
cd /root

tar -xvf qt-everywhere-opensource-src-5.15.18.tar.xz
echo "qt 源代码解压完成完成。。。。。。"

cd /root/qt-everywhere-src-5.15.18

./configure \
-opensource \
-confirm-license \
-release \
-platform linux-g++ \
-gui \
-widgets \
-xcb \
-fontconfig \
-system-freetype \
-opengl desktop \
-shared \
-qt-sqlite \
-feature-sql-sqlite \
--no-feature-cups \
-no-dbus \
-make libs \
-make tools \
-qt-zlib \
-qt-libjpeg \
-qt-libpng \
-nomake examples \
-nomake tests \
\
-skip qtwebengine \
-skip qtdeclarative \
-skip qtquickcontrols \
-skip qtquickcontrols2 \
-skip qtquicktimeline \
-skip qtquick3d \
-skip qtgraphicaleffects \
-skip qtlottie \
-skip qtmultimedia \
-skip qtserialport \
-skip qtserialbus \
-skip qtconnectivity \
-skip qtsensors \
-skip qtlocation \
-skip qtcharts \
-skip qtgamepad \
-skip qtspeech \
-skip qtvirtualkeyboard \
-skip qtwebchannel \
-skip qtwebglplugin \
-skip qtwebsockets \
-skip qtwebview \
-skip qtnetworkauth \
-skip qt3d \
-skip qtcanvas3d \
-skip qtdatavis3d \
-skip qtandroidextras \
-skip qtmacextras \
-skip qtwinextras \
-skip qtactiveqt \
-skip qtwayland \
-skip qtscript \
-skip qtscxml \
-skip qtxmlpatterns \
-skip qtdoc \
-skip qttranslations

echo "qt 动态编译环境检查完成。。。。。。"

make -j$(nproc)

echo "qt 动态编译完成。。。。。。"

make install

echo "qt 动态安装完成。。。。。。"

cd /usr/local && tar -zcvf Qt-5.15.18-shared.tar.gz Qt-5.15.18 && rm -rf Qt-5.15.18 && mv Qt-5.15.18-shared.tar.gz /root/

echo "==================================================================================="


cd /root/ && rm -rf qt-everywhere-src-5.15.18
tar -xvf qt-everywhere-opensource-src-5.15.18.tar.xz
echo "qt 源代码解压完成完成。。。。。。"

cd /root/qt-everywhere-src-5.15.18

./configure \
-opensource \
-confirm-license \
-release \
-platform linux-g++ \
-gui \
-widgets \
-xcb \
-fontconfig \
-system-freetype \
-opengl desktop \
-static \
-qt-sqlite \
-feature-sql-sqlite \
--no-feature-cups \
-no-dbus \
-make libs \
-make tools \
-qt-zlib \
-qt-libjpeg \
-qt-libpng \
-nomake examples \
-nomake tests \
\
-skip qtwebengine \
-skip qtdeclarative \
-skip qtquickcontrols \
-skip qtquickcontrols2 \
-skip qtquicktimeline \
-skip qtquick3d \
-skip qtgraphicaleffects \
-skip qtlottie \
-skip qtmultimedia \
-skip qtserialport \
-skip qtserialbus \
-skip qtconnectivity \
-skip qtsensors \
-skip qtlocation \
-skip qtcharts \
-skip qtgamepad \
-skip qtspeech \
-skip qtvirtualkeyboard \
-skip qtwebchannel \
-skip qtwebglplugin \
-skip qtwebsockets \
-skip qtwebview \
-skip qtnetworkauth \
-skip qt3d \
-skip qtcanvas3d \
-skip qtdatavis3d \
-skip qtandroidextras \
-skip qtmacextras \
-skip qtwinextras \
-skip qtactiveqt \
-skip qtwayland \
-skip qtscript \
-skip qtscxml \
-skip qtxmlpatterns \
-skip qtdoc \
-skip qttranslations

echo "qt 静态编译环境检查完成。。。。。。"

make -j$(nproc)

echo "qt 静态编译完成。。。。。。"

make install

echo "qt 静态安装完成。。。。。。"

cd /usr/local && tar -zcvf Qt-5.15.18-static.tar.gz Qt-5.15.18 && rm -rf Qt-5.15.18 && mv Qt-5.15.18-static.tar.gz /root/