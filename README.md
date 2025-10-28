# Duplexer

**Automatic PDF Duplex Scanning Assistant**

Duplexer is a containerized service that automatically merges dual-sided (duplex) PDF scans that were created by scanning odd and even pages separately. Perfect for home offices and document management workflows.

## 🎯 Problem Solved

When scanning double-sided documents on scanners without automatic duplex capability:
1. You scan all odd pages (1, 3, 5, 7...) as one PDF
2. Flip the paper stack and scan all even pages (2, 4, 6, 8...) as another PDF  
3. Manually merge and reorder these files

Duplexer automates this tedious process!

## ✨ Features

- **Real-time monitoring** of inbox folder for new PDF files
- **Automatic merging** of odd/even page PDFs with proper ordering
- **Integration** with Paperless-NGX document management
- **Robust error handling** and logging
- **Docker containerized** for easy deployment
- **NAS-ready** deployment configuration

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Access to target directories (NAS volumes or local folders)

### 1. Clone and Build

```bash
git clone https://github.com/Kymr10n/duplexer.git
cd duplexer
make build-local
```

### 2. Configure Volumes

Edit `deploy/docker-compose.yml` to match your setup:

```yaml
volumes:
  - /your/scan/inbox:/duplex-inbox:rw
  - /your/paperless/consume:/paperless-consume:rw  
  - /your/logs/path:/logs:rw
```

### 3. Deploy

```bash
# For local deployment
docker compose -f deploy/docker-compose.yml up -d

# For remote NAS deployment  
make up
```

## 📖 Usage

1. **Scan odd pages** - save as any PDF name (e.g., `scan1.pdf`)
2. **Scan even pages** - save as any PDF name (e.g., `scan2.pdf`)
3. **Drop both files** into the monitored inbox folder
4. **Wait for processing** - merged file appears in Paperless consume folder
5. **Check logs** if needed: `make logs`

### File Processing Flow

```
Inbox: scan1.pdf (odd pages: 1,3,5,7)
       scan2.pdf (even pages: 8,6,4,2)
              ↓
       [Duplexer Processing]
              ↓
Output: duplex_20241028_143022.pdf (pages: 1,2,3,4,5,6,7,8)
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `INBOX` | `/duplex-inbox` | Directory to monitor for PDF files |
| `OUTBOX` | `/paperless-consume` | Output directory for merged PDFs |
| `LOGFILE` | `/logs/duplexer.log` | Log file location |

### Docker Volumes

- **Inbox**: Where you drop PDF files to be processed
- **Outbox**: Where merged PDFs are delivered (typically Paperless consume folder)
- **Logs**: Persistent logging for monitoring and debugging

## 📊 Monitoring

### Check Status
```bash
# View real-time logs
make logs

# Check container status  
docker ps | grep duplexer

# Manual processing trigger
docker exec duplexer /app/merge_once.sh
```

### Log Format
```
[2024-10-28 14:30:22] [watch] duplexer watcher started, monitoring /duplex-inbox
[2024-10-28 14:31:15] processing pair:
[2024-10-28 14:31:15]   odd-pages file:   /duplex-inbox/scan1.pdf
[2024-10-28 14:31:15]   even-pages file:  /duplex-inbox/scan2.pdf  
[2024-10-28 14:31:15]   target output:    /paperless-consume/duplex_20241028_143115.pdf
[2024-10-28 14:31:17] merged file delivered to paperless consume
[2024-10-28 14:31:17] source pdfs removed, pair complete
```

## 🛠️ Development

### Local Development
```bash
# Build image locally
make build-local

# Run with local volumes for testing
docker run -v $(pwd)/test-inbox:/duplex-inbox \
           -v $(pwd)/test-output:/paperless-consume \
           -v $(pwd)/logs:/logs \
           duplexer:latest
```

### Makefile Commands
- `make build-local` - Build Docker image locally
- `make build-remote` - Build on remote NAS context
- `make up` - Deploy to remote NAS
- `make down` - Stop remote deployment
- `make logs` - View container logs

## 🐛 Troubleshooting

### Common Issues

**No files being processed:**
- Check inbox permissions: `ls -la /your/scan/inbox`
- Verify container is running: `docker ps`
- Check logs for errors: `make logs`

**PDFs not merging correctly:**
- Ensure files are valid PDFs: `file /path/to/file.pdf`
- Check available disk space in container
- Verify pdftk installation: `docker exec duplexer pdftk --version`

**Files stuck in inbox:**
- Only processes when exactly 2 PDFs are present
- Remove extra files or add missing pair
- Check file permissions and ownership

### Manual Recovery
```bash
# Access container shell
docker exec -it duplexer bash

# Manual merge execution  
/app/merge_once.sh

# Check PDF validity
pdftk input.pdf dump_data
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and test
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- Built with [pdftk](https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/) for PDF manipulation
- Designed for [Paperless-NGX](https://github.com/paperless-ngx/paperless-ngx) integration
- Optimized for Synology NAS deployment