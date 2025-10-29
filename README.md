# Duplexer

<div align="center">
  <img src="logo.png" alt="Duplexer Logo" width="200"/>
</div>

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
- SSH access to your NAS
- Access to target directories (NAS volumes or local folders)

### 1. Initial Setup

```bash
git clone https://github.com/Kymr10n/duplexer.git
cd duplexer
./setup.sh
```

The setup script will:
- Create a `.env` configuration file from template
- Check prerequisites and connectivity
- Create necessary directories on your NAS
- Guide you through configuration

### 2. Configure Environment

Edit `.env` file with your NAS details:

```bash
# Your NAS configuration
NAS_HOST=your_username@your_nas_hostname
DOCKER_CONTEXT=your_docker_context_name
NAS_DUPLEXER_PATH=/volume1/services/duplexer
NAS_PAPERLESS_PATH=/volume1/services/paperless
```

### 3. Deploy

```bash
# Build and deploy
make build-remote
make up

# Check status
make status
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

Duplexer uses a `.env` file for configuration (not synced with git):

| Variable | Default | Description |
|----------|---------|-------------|
| `NAS_HOST` | `username@your-nas-hostname` | SSH connection to NAS |
| `DOCKER_CONTEXT` | `your-nas-context` | Docker context name |
| `NAS_DUPLEXER_PATH` | `/volume1/services/duplexer` | Base path on NAS |
| `NAS_PAPERLESS_PATH` | `/volume1/services/paperless` | Paperless path on NAS |
| `INBOX_PATH` | `${NAS_DUPLEXER_PATH}/inbox` | Directory to monitor for PDFs |
| `CONSUME_PATH` | `${NAS_PAPERLESS_PATH}/consume` | Output directory for merged PDFs |
| `LOGS_PATH` | `${NAS_DUPLEXER_PATH}/logs` | Log file location |

### Container Environment

The following environment variables are available inside the container:

| Variable | Default | Description |
|----------|---------|-------------|
| `INBOX` | `/duplex-inbox` | Directory to monitor for PDF files |
| `OUTBOX` | `/paperless-consume` | Output directory for merged PDFs |
| `LOGFILE` | `/logs/duplexer.log` | Log file location |
| `BACKUP_DIR` | `/logs/backup` | Backup directory for original files |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARN, ERROR) |

### Docker Volumes

Volume mappings are configured automatically from your `.env` file:

- **Inbox**: `${INBOX_PATH}:/duplex-inbox` - Where you drop PDF files to be processed
- **Outbox**: `${CONSUME_PATH}:/paperless-consume` - Where merged PDFs are delivered
- **Logs**: `${LOGS_PATH}:/logs` - Persistent logging for monitoring and debugging

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
