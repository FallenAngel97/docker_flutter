# ----------------------------------------------------------------------------------------
#                                        Dockerfile
# ----------------------------------------------------------------------------------------
# image:       plugfox/flutter:${VERSION}-android
# repository:  https://github.com/plugfox/docker_flutter
# license:     MIT
# requires:
# + alpine:latest
# + plugfox/flutter:<version>
# authors:
# + Plague Fox <PlugFox@gmail.com>
# + Maria Melnik
# + Dmitri Z <z-dima@live.ru>
# + DoumanAsh <douman@gmx.se>
# ----------------------------------------------------------------------------------------

ARG VERSION="stable"
# ANDROID_SDK_TOOLS_VERSION Comes from https://developer.android.com/studio/#command-tools
ARG ANDROID_SDK_TOOLS_VERSION=8512546
ARG ANDROID_HOME="/opt/android"

FROM alpine:latest as build

USER root

ARG ANDROID_PLATFORM_VERSION
ARG ANDROID_SDK_TOOLS_VERSION
ARG ANDROID_HOME

WORKDIR /

ENV ANDROID_HOME=$ANDROID_HOME \
    ANDROID_SDK_ROOT=$ANDROID_HOME \
    ANDROID_TOOLS_ROOT=$ANDROID_HOME \
    PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

# Install linux dependency and utils
RUN set -eux; apk --no-cache add bash curl wget unzip openjdk11-jdk upx \
    && rm -rf /tmp/* /var/cache/apk/* \
    && mkdir -p ${ANDROID_HOME}/cmdline-tools /root/.android

# Install the Android SDK Dependency.
RUN set -eux; wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_TOOLS_VERSION}_latest.zip -O /tmp/android-sdk-tools.zip \
    && unzip -q /tmp/android-sdk-tools.zip -d /tmp/ \
    && mv /tmp/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest/ \
    && rm -rf /tmp/* \
    && touch /root/.android/repositories.cfg \
    && yes | sdkmanager --sdk_root=${ANDROID_HOME} --licenses \
    && sdkmanager --sdk_root=${ANDROID_HOME} --install "platform-tools" 

# Create android dependencies
RUN set -eux; \
    for f in \
    ${ANDROID_HOME} \
    /root \
    ; do \
    dir="$(dirname "$f")"; \
    mkdir -p "/build_android_dependencies$dir"; \
    cp --archive --link --dereference --no-target-directory "$f" "/build_android_dependencies$f"; \
    done

# Create new clear layer
FROM plugfox/flutter:${VERSION} as production

ARG VERSION
ARG ANDROID_SDK_TOOLS_VERSION
ARG ANDROID_HOME

# Add enviroment variables
ENV ANDROID_HOME=$ANDROID_HOME \
    ANDROID_SDK_ROOT=$ANDROID_HOME \
    ANDROID_TOOLS_ROOT=$ANDROID_HOME \
    PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

# Copy android dependencies
COPY --from=build /build_android_dependencies/ /

#RUN mkdir -p /tmp && find / -xdev | sort > /tmp/before.txt

# Init android dependency and utils
RUN set -eux; apk add --no-cache openjdk11-jdk upx \
    && cd "${FLUTTER_HOME}/bin" \
    && yes "y" | flutter doctor --android-licenses \
    && dart --disable-analytics \
    && flutter config --no-analytics --enable-android \
    && flutter precache --universal --android \
    && sdkmanager --sdk_root=${ANDROID_HOME} --install "platform-tools" "emulator" \
    && sdkmanager --list_installed > /root/sdkmanager-list-installed.txt \
    && upx --ultra-brute /opt/android/cmdline-tools/latest/bin/apkanalyzer \
    #&& upx --ultra-brute /opt/android/cmdline-tools/latest/bin/sdkmanager \
    && upx --ultra-brute /opt/android/cmdline-tools/latest/bin/avdmanager \
    && upx --ultra-brute /opt/android/platform-tools/adb \
    && upx --ultra-brute /opt/android/platform-tools/fastboot \
    && upx --ultra-brute /opt/android/platform-tools/sqlite3 \
    && upx --ultra-brute /opt/android/platform-tools/mke2fs \
    && upx --ultra-brute /opt/flutter/bin/cache/dart-sdk/bin/dart \
    && upx --ultra-brute /opt/flutter/bin/cache/dart-sdk/bin/utils/gen_snapshot \
    && upx --ultra-brute /opt/flutter/bin/cache/dart-sdk/bin/utils/wasm-opt \
    && upx --ultra-brute /opt/flutter/bin/cache/dart-sdk/bin/dartaotruntime \
    && upx --ultra-brute /opt/flutter/bin/cache/artifacts/engine/linux-x64/flutter_tester \
    && upx --ultra-brute /opt/flutter/bin/cache/artifacts/engine/linux-x64/impellerc \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/apk/* \
    /usr/share/man/* /usr/share/doc /opt/flutter/CONTRIBUTING.md /opt/flutter/CODE_OF_CONDUCT.md \
    /opt/flutter/AUTHORS /opt/flutter/CODEOWNERS /opt/flutter/PATENT_GRANT /opt/flutter/README.md \
    /opt/flutter/TESTOWNERS /opt/flutter/examples

# Build demo project
#RUN set -eux; cd "/home/" \
#    && flutter create --pub -a kotlin --project-name warmup --platforms android -t app warmup \
#    && cd warmup \
#    && flutter pub get \
#    && flutter pub upgrade --major-versions \
#    && flutter build apk --release --pub --shrink --target-platform android-arm,android-arm64,android-x64 \
#    && cd .. && rm -rf warmup

#RUN cd / && find / -xdev | sort > /tmp/after.txt

# Add lables
LABEL name="FallenAngel97/flutter:${VERSION}-android" \
    description="Alpine with flutter & dart for android" \
    flutter.channel="${VERSION}" \
    flutter.version="${VERSION}" \
    android.home="${ANDROID_HOME}"

# By default
USER root
WORKDIR /build
SHELL [ "/bin/bash", "-c" ]
CMD [ "flutter", "doctor" ]
