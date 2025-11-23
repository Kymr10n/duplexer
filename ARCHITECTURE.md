# Architecture & Prerequisites

## 🏗️ System Architecture

Duplexer follows a clean containerized architecture where tools and dependencies are properly isolated:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Developer       │    │ NAS Host        │    │ Docker          │
│ Machine         │    │ (Minimal)       │    │ Container       │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • Git           │    │ • Docker        │    │ • pdftk         │
│ • Make          │    │ • SSH           │    │ • qpdf          │
│ • Docker CLI    │    │ • File system   │    │ • inotify-tools │
│ • SSH           │    │ • Directory     │    │ • Application   │
│ • Testing tools │    │   structure     │    │   code          │
│   (ghostscript) │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚫 What NOT to Install on NAS Host

**Never install these directly on the NAS:**
- PDF processing tools (pdftk, qpdf, ghostscript)
- Application dependencies
- Language runtimes (unless system dependencies)
- Development tools

**Why?**
- Pollutes the host system
- Version conflicts with system packages
- Harder to maintain and update
- Security risks
- Breaks container isolation

## ✅ What SHOULD Be on Each System

### Developer Machine
**Required:**
- `git` - Version control
- `make` - Build system
- `docker` - Container management
- `ssh` - Remote access
- Docker context pointing to NAS

**Optional (for testing):**
- `ghostscript` (ps2pdf) - Generate test PDFs
- `pdflatex` - Alternative PDF generation
- `curl` - API testing
- `jq` - JSON processing

### NAS Host (Minimal)
**Required:**
- `docker` - Container runtime
- `ssh` - Remote access
- Standard Unix tools (`bash`, `ls`, `mkdir`, etc.)

**Optional:**
- `inotify-tools` - If using host-level file watching (not recommended)

**Directory Structure:**
```
# User accessible directories (file share)
/volume1/services/duplexer/
└── inbox/          # PDF input directory (user uploads here)

/volume1/services/paperless/
└── consume/        # Final output directory

# Docker managed directories (secure location)
/volume2/docker/duplexer/
├── logs/           # Application logs
├── config/         # Configuration files
├── outbox/         # Temporary output
└── temp/           # Temporary processing files
```

### Docker Container
**All application dependencies:**
- `pdftk-java` - PDF manipulation
- `qpdf` - PDF processing library
- `inotify-tools` - File watching
- `file` - File type detection
- `coreutils` - Standard utilities
- Application code and scripts

## 🔧 Installation Commands

### Developer Machine Setup
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install git make docker.io ssh

# macOS (with Homebrew)
brew install git make docker ssh

# Create Docker context
docker context create your-nas-context --docker "host=ssh://user@nas-hostname"
```

### NAS Host Setup
```bash
# Usually Docker is pre-installed on NAS systems
# If not, follow NAS-specific Docker installation guides

# Create directory structure
# User accessible directories
mkdir -p /volume1/services/duplexer/inbox
mkdir -p /volume1/services/paperless/consume

# Docker managed directories (secure location)
mkdir -p /volume2/docker/duplexer/{logs,config,outbox,temp}
```

### Container (Automatic via Dockerfile)
The container automatically includes all required tools via the Dockerfile:
```dockerfile
RUN apt-get update && apt-get install -y \
    pdftk-java \
    qpdf \
    inotify-tools \
    coreutils \
    file \
    && apt-get clean
```

## 📋 Prerequisites Checker

Run the prerequisites checker to validate your setup:

```bash
make check-prereqs
```

This will:
- ✅ Check developer machine tools
- ✅ Verify SSH connectivity to NAS
- ✅ Validate NAS directory structure
- ✅ Confirm Docker context setup
- ✅ Test container tool availability (if running)
- ❌ **NOT** check for tools installed on NAS host (by design)

## 🛠️ Troubleshooting

### "Missing pdftk on NAS"
**Wrong approach:** `ssh nas-host "sudo apt install pdftk"`
**Correct approach:** Check Dockerfile includes `pdftk-java`

### "PDF processing fails"
1. Check container logs: `make logs`
2. Verify container has tools: `docker exec duplexer pdftk --version`
3. Rebuild container if needed: `make build-remote`

### "Permission errors"
1. Check directory permissions on NAS
2. Verify user/group IDs in docker-compose
3. Ensure Docker daemon has access to mounted volumes

## 🔒 Security Best Practices

1. **Principle of Least Privilege**: Only install what's needed where it's needed
2. **Container Isolation**: Keep application dependencies in containers
3. **Host Minimalism**: Keep NAS host clean and minimal
4. **Version Control**: All dependencies declared in Dockerfile
5. **Reproducibility**: Anyone can rebuild identical environment

This architecture ensures:
- Clean separation of concerns
- Easy maintenance and updates
- Consistent environments across developers
- Security through isolation
- Simplified troubleshooting