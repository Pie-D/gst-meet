FROM docker.io/library/alpine:3.20.0 AS builder

# Dependencies để build Rust & GStreamer plugins
RUN apk --no-cache --update upgrade --ignore alpine-baselayout \
 && apk --no-cache add \
    build-base \
    git \
    cmake \
    clang16-dev \
    clang16-libs \
    curl \
    openssl-dev \
    gstreamer-dev \
    gst-plugins-base-dev \
    gst-plugins-bad-dev \
    libnice-dev \
    rust-bindgen

# Install Rust (rustup) - sử dụng phiên bản ổn định (stable) mới nhất
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain 1.85.0 \
 && rustup target add x86_64-unknown-linux-musl

# Kiểm tra lại phiên bản Rust rõ ràng
RUN rustc --version && cargo --version

# Clone và build gst-meet
WORKDIR /build
COPY . .
RUN cargo build --release \
 && cp target/release/gst-meet /usr/local/bin/

# build gst-plugin-webrtchttp
WORKDIR /build/plugins

RUN cargo install cargo-c \
 && git clone --recursive https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs.git \
 && cd gst-plugins-rs \
 && cargo cbuild -p gst-plugin-webrtchttp --release \
 && mkdir -p /gst-plugins/lib/gstreamer-1.0 \
 && cp target/x86_64-unknown-linux-musl/release/libgstwebrtchttp.so /gst-plugins/lib/gstreamer-1.0/

# Runtime image
FROM docker.io/library/alpine:3.20.0

RUN apk --update --no-cache upgrade --ignore alpine-baselayout \
 && apk --no-cache add \
    openssl \
    ca-certificates \
    gstreamer \
    gst-plugins-base \
    gst-plugins-good \
    gst-plugins-bad \
    gst-plugins-ugly \
    gst-libav \
    libnice \
    libnice-gstreamer

# Copy binary
COPY --from=builder /usr/local/bin/gst-meet /usr/local/bin

# Copy chúng ta đã compile trước đó
COPY --from=builder /gst-plugins/lib/gstreamer-1.0/libgstwebrtchttp.so /usr/lib/gstreamer-1.0/

# Kiểm tra plugin
RUN gst-inspect-1.0 whipsink && gst-inspect-1.0 whepsrc

ENTRYPOINT ["/usr/local/bin/gst-meet"]