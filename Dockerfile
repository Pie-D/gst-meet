FROM docker.io/library/alpine:3.20.0 AS builder

# Install dependencies (musl-dev pkgconfig là bắt buộc)
RUN apk --no-cache --update upgrade --ignore alpine-baselayout \
 && apk --no-cache add \
    build-base \
    git \
    cmake \
    clang16-dev \
    clang16-libs \
    curl \
    pkgconfig \
    musl-dev \
    openssl-dev \
    gstreamer-dev \
    gst-plugins-base-dev \
    gst-plugins-bad-dev \
    gst-plugins-good-dev \
    libnice-dev \
    rust-bindgen

# Install Rust toolchain
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.85.0 \
 && rustup target add x86_64-unknown-linux-musl

# Explicitly set Rust flags for musl build
ENV RUSTFLAGS="-C target-feature=-crt-static" \
    CC=musl-gcc

# Verify Rust version clearly
RUN rustc --version && cargo --version

# Clone and build your project
WORKDIR /build
COPY . .

RUN cargo build --release --target x86_64-unknown-linux-musl \
 && cp target/x86_64-unknown-linux-musl/release/gst-meet /usr/local/bin/

# Build gst-plugin-webrtchttp
WORKDIR /build/plugins

RUN cargo install cargo-c \
 && git clone --recursive https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs.git \
 && cd gst-plugins-rs \
 && cargo cbuild -p gst-plugin-webrtchttp --release --target x86_64-unknown-linux-musl \
 && mkdir -p /gst-plugins/lib/gstreamer-1.0 \
 && cp target/x86_64-unknown-linux-musl/release/libgstwebrtchttp.so /gst-plugins/lib/gstreamer-1.0/

# runtime image
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

# copy binary
COPY --from=builder /usr/local/bin/gst-meet /usr/local/bin/

# copy plugin so file
COPY --from=builder /gst-plugins/lib/gstreamer-1.0/libgstwebrtchttp.so /usr/lib/gstreamer-1.0/

# test để đảm bảo plugin chạy được
RUN gst-inspect-1.0 whipsink && gst-inspect-1.0 whepsrc

ENTRYPOINT ["/usr/local/bin/gst-meet"]