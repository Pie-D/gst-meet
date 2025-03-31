FROM rust:1.85.1 as builder

# Cài đặt dependencies build
RUN apt-get update && apt-get install -y \
    build-essential \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstreamer-plugins-bad1.0-dev \
    libnice-dev \
    libssl-dev \
    cargo \
    cmake \
    clang \
    llvm \
    rustc \
    pkg-config \
    ca-certificates \
    git && \
    rm -rf /var/lib/apt/lists/*

# Clone và build gst-meet binary
COPY . .
RUN cargo build --release -p gst-meet

# Clone và build gst-plugin-webrtchttp (plugin WHIP/WHEP chuẩn)
WORKDIR /build
RUN cargo install cargo-c && \
    git clone --recursive https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs.git && \
    cd gst-plugins-rs && \
    cargo cbuild -p gst-plugin-webrtchttp --release && \
    mkdir -p /gst-plugins/lib/gstreamer-1.0 && \
    cp target/x86_64-unknown-linux-gnu/release/libgstwebrtchttp.so /gst-plugins/lib/gstreamer-1.0/

# Stage 2: Runtime image
FROM debian:bookworm-slim

# cài đặt runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl3 \
    gstreamer1.0-tools \
    libgstreamer1.0-0 \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    libnice10 \
    gstreamer1.0-nice \
    openjdk-17-jre \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy binaries đã build
COPY --from=builder /usr/local/bin/gst-meet /usr/local/bin/gst-meet
COPY --from=builder /gst-plugins/lib/gstreamer-1.0/libgstwebrtchttp.so /usr/lib/x86_64-linux-gnu/gstreamer-1.0/

# Kiểm tra plugins từ bước build trước
RUN gst-inspect-1.0 whipsink && gst-inspect-1.0 whepsrc

ENTRYPOINT ["/usr/local/bin/gst-meet"]
