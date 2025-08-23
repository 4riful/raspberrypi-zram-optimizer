# 🤝 Contributing to Raspberry Pi ZRAM Optimizer

> **Thank you for your interest in contributing!**  
> This document provides guidelines and information for contributors to help make this project even better.

---

## 🎯 How to Contribute

We welcome contributions from the community! Here are several ways you can help:

- 🐛 **Report Bugs** - Help us identify and fix issues
- 💡 **Suggest Features** - Propose new ideas and improvements
- 📝 **Improve Documentation** - Help make our docs clearer and more comprehensive
- 🔧 **Submit Code** - Fix bugs, add features, or improve performance
- 🧪 **Test & Validate** - Test on different hardware configurations
- 🌍 **Translate** - Help make the project accessible to more users

---

## 🚀 Getting Started

### 📋 Prerequisites

- **Git** - For version control
- **Bash** - For running and testing scripts
- **Raspberry Pi** (or similar ARM device) - For testing
- **Linux knowledge** - Basic understanding of system administration

### 🔧 Development Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/raspberrypi-zram-optimizer.git
cd raspberrypi-zram-optimizer

# Create a new branch for your changes
git checkout -b feature/your-feature-name

# Make your changes and test them
# ... your modifications ...

# Commit your changes
git commit -m "feat: add your feature description"

# Push to your fork
git push origin feature/your-feature-name
```

---

## 📝 Code Style Guidelines

### 🐚 Bash Script Standards

- **Use `set -euo pipefail`** - Ensure scripts fail fast and safely
- **Quote all variables** - Use `"$variable"` instead of `$variable`
- **Use meaningful variable names** - Avoid single-letter variables
- **Add proper error handling** - Include error messages and exit codes
- **Include usage functions** - Help users understand how to use scripts

### 📚 Documentation Standards

- **Use clear, concise language** - Write for users of all skill levels
- **Include examples** - Show practical usage scenarios
- **Use proper markdown formatting** - Consistent with existing style
- **Add emojis and visual elements** - Make docs engaging and scannable

### 🔍 Testing Requirements

- **Test on real hardware** - Verify functionality on actual Raspberry Pi devices
- **Test edge cases** - Consider low-memory and high-load scenarios
- **Validate error handling** - Ensure scripts fail gracefully
- **Performance testing** - Measure impact on system resources

---

## 🐛 Bug Reports

### 📋 Bug Report Template

When reporting a bug, please include:

```markdown
## 🐛 Bug Description

**What happened?**
A clear description of the issue.

**Expected behavior**
What you expected to happen.

**Actual behavior**
What actually happened.

**Steps to reproduce**
1. Step 1
2. Step 2
3. Step 3

**Environment**
- Device: [e.g., Raspberry Pi 3B+, 4B]
- OS: [e.g., Raspberry Pi OS, Ubuntu]
- Kernel: [e.g., 5.15.0]
- Script version: [e.g., commit hash]

**Additional context**
Any other relevant information, logs, or screenshots.
```

---

## 💡 Feature Requests

### 📋 Feature Request Template

```markdown
## 💡 Feature Request

**Problem statement**
Describe the problem this feature would solve.

**Proposed solution**
Describe your proposed solution.

**Alternative solutions**
Any alternatives you've considered.

**Additional context**
Screenshots, mockups, or examples if applicable.
```

---

## 🔧 Pull Request Process

### 📋 PR Checklist

Before submitting a pull request, ensure:

- [ ] **Code follows style guidelines** - Consistent with project standards
- [ ] **Tests pass** - All functionality works as expected
- [ ] **Documentation updated** - README, comments, and docs reflect changes
- [ ] **Commit messages clear** - Use conventional commit format
- [ ] **No breaking changes** - Unless explicitly documented and necessary

### 📝 Commit Message Format

Use conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `style:` - Code style changes
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

**Examples:**
```
feat(script): add support for custom compression algorithms
fix(service): resolve systemd service startup issue
docs(readme): add troubleshooting section
```

---

## 🧪 Testing Guidelines

### 🔍 Testing Checklist

- [ ] **Basic functionality** - Script runs without errors
- [ ] **Error handling** - Graceful failure with clear messages
- [ ] **Edge cases** - Low memory, high load scenarios
- [ ] **Different hardware** - Test on various Raspberry Pi models
- [ ] **Different OS versions** - Verify compatibility across distributions
- [ ] **Performance impact** - Measure CPU and memory usage
- [ ] **Thermal behavior** - Monitor temperature under load

### 🚀 Testing Commands

```bash
# Test script functionality
sudo ./scripts/zram-setup.sh start
sudo ./scripts/zram-setup.sh status
sudo ./scripts/zram-setup.sh stop

# Verify ZRAM setup
zramctl
swapon --show
free -h

# Test error conditions
sudo -u nobody ./scripts/zram-setup.sh  # Should fail gracefully
```

---

## 📚 Documentation Contributions

### 📖 Areas for Improvement

- **Installation guides** - Step-by-step setup instructions
- **Configuration examples** - Sample configurations for different use cases
- **Troubleshooting guides** - Common issues and solutions
- **Performance tuning** - Optimization tips and best practices
- **Hardware compatibility** - Supported devices and requirements

### ✍️ Writing Style

- **Use active voice** - "The script creates..." not "The script is created by..."
- **Be specific** - Include exact commands and expected output
- **Use examples** - Show real-world usage scenarios
- **Include warnings** - Highlight potential risks and precautions
- **Keep it scannable** - Use headers, lists, and tables for easy reading

---

## 🔒 Security Considerations

### 🛡️ Security Guidelines

- **Never commit secrets** - API keys, passwords, or sensitive data
- **Validate inputs** - Sanitize user inputs and environment variables
- **Use minimal permissions** - Request only necessary privileges
- **Log security events** - Record authentication and authorization attempts
- **Follow principle of least privilege** - Grant minimal required access

### 🚨 Reporting Security Issues

If you discover a security vulnerability:

1. **Do not open a public issue**
2. **Email security@yourdomain.com** (replace with actual security contact)
3. **Include detailed description** of the vulnerability
4. **Wait for response** before disclosing publicly

---

## 🌍 Internationalization

### 🌐 Translation Guidelines

- **Use clear, simple language** - Avoid idioms and complex phrases
- **Provide context** - Include examples and explanations
- **Test with native speakers** - Ensure accuracy and natural flow
- **Maintain consistency** - Use consistent terminology across languages
- **Consider cultural differences** - Adapt examples and references appropriately

---

## 📞 Getting Help

### 🆘 Support Channels

- **GitHub Issues** - For bugs and feature requests
- **GitHub Discussions** - For questions and general discussion
- **Documentation** - Check existing docs first
- **Community Forums** - Raspberry Pi forums and communities

### 👥 Community Guidelines

- **Be respectful** - Treat others with kindness and respect
- **Help others** - Share knowledge and assist newcomers
- **Stay on topic** - Keep discussions relevant to the project
- **Follow the code of conduct** - Maintain a welcoming environment

---

## 🎉 Recognition

### 🌟 Contributor Recognition

We appreciate all contributions! Contributors will be:

- **Listed in README** - Acknowledged for significant contributions
- **Mentioned in releases** - Credited for features and fixes
- **Invited to discussions** - Participate in project planning
- **Given maintainer access** - For trusted, active contributors

---

## 📄 License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

<div align="center">

**Thank you for contributing to the Raspberry Pi community! 🚀**

*Your contributions help make this project better for everyone.*

</div>
