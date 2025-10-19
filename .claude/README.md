# Claude Code Configuration for terraform-k8s-mac

This directory contains the Claude Code configuration for the terraform-k8s-mac project.

## Directory Structure

```
.claude/
├── agents/              # 8 specialized AI agents
│   ├── coordinator.md      # Main orchestrator agent
│   ├── backend-agent.md    # Backend/API development
│   ├── frontend-agent.md   # Frontend/UI development
│   ├── qa-agent.md         # Testing and quality assurance
│   ├── docs-agent.md       # Documentation specialist
│   ├── review-agent.md     # Code review and security
│   ├── devops-agent.md     # DevOps, Kubernetes, Terraform
│   └── security-agent.md   # Security auditing and compliance
├── commands/            # 4 workflow commands
│   ├── feature.md          # Full-stack feature development
│   ├── bugfix.md           # Systematic bug fixing
│   ├── refactor.md         # Safe refactoring workflow
│   └── pr-review.md        # Comprehensive PR review
├── hooks/               # Event-driven automation
│   ├── approval-gate.sh    # Approval for high-risk operations
│   └── workflow-notification.sh  # Slack notifications
└── mcp-settings.json    # MCP server configuration
```

## Quick Start

### 1. Copy Environment Configuration

```bash
cp .env.example .env
```

### 2. Configure Credentials

Edit `.env` and add your credentials:

```bash
# Minimum required for basic functionality
GITHUB_TOKEN=ghp_your_token_here

# Optional but recommended
JIRA_BASE_URL=https://gjrjr4545.atlassian.net
JIRA_EMAIL=your-email@example.com
JIRA_API_TOKEN=your_token_here

SLACK_BOT_TOKEN=xoxb_your_token_here
SLACK_TEAM_ID=T1234567890
```

### 3. Load Environment Variables

```bash
export $(cat .env | xargs)
```

### 4. Start Using Claude Code

```bash
claude

# Try a workflow command
> /feature "Add monitoring dashboard for Kubernetes cluster"
```

## Available Agents

### Coordinator Agent
**Purpose**: Orchestrates complex multi-agent workflows
**Use when**: You need to coordinate frontend, backend, testing, documentation, and reviews

Example:
```
Use the coordinator to build a complete user authentication system
```

### Backend Agent
**Purpose**: API development, database operations, Kubernetes/infrastructure
**Use when**: Working on server-side code, APIs, databases, or K8s manifests

Example:
```
Use the backend-agent to create a REST API for managing Kubernetes pods
```

### Frontend Agent
**Purpose**: UI components, client-side logic, styling
**Use when**: Building user interfaces or client-side features

Example:
```
Use the frontend-agent to create a dashboard for visualizing cluster metrics
```

### QA Agent
**Purpose**: Testing, quality assurance, test automation
**Use when**: Creating tests or ensuring code quality

Example:
```
Use the qa-agent to add comprehensive tests for the user service
```

### Documentation Agent
**Purpose**: Technical documentation, API docs, README files
**Use when**: Creating or updating documentation

Example:
```
Use the docs-agent to document the Kubernetes deployment process
```

### Review Agent
**Purpose**: Code review, security analysis, performance optimization
**Use when**: Reviewing code for quality, security, or performance issues

Example:
```
Use the review-agent to audit the authentication implementation for security issues
```

### DevOps Agent
**Purpose**: Infrastructure, CI/CD, Kubernetes operations, Terraform
**Use when**: Working on infrastructure, deployments, or operational tasks

Example:
```
Use the devops-agent to create a Terraform module for the monitoring stack
```

### Security Agent
**Purpose**: Security auditing, vulnerability assessment, compliance
**Use when**: Conducting security reviews or implementing security controls

Example:
```
Use the security-agent to perform a security audit of the API endpoints
```

## Workflow Commands

### /feature - Feature Development
Orchestrates complete feature development from planning to PR creation.

```bash
/feature "Add user authentication with JWT"
```

**What it does:**
1. Plans the feature with the coordinator
2. Backend agent creates API endpoints
3. Frontend agent builds UI components
4. QA agent writes comprehensive tests
5. Docs agent updates documentation
6. Review agent performs code review
7. Creates GitHub PR

### /bugfix - Bug Fixing
Systematic bug fixing with reproduction, fix, testing, and verification.

```bash
/bugfix "Login fails when email contains special characters"
```

**What it does:**
1. QA agent reproduces the bug
2. Appropriate agent implements the fix
3. QA agent adds regression tests
4. Review agent verifies the fix
5. Docs agent updates documentation
6. Creates GitHub PR

### /refactor - Safe Refactoring
Incremental, test-driven refactoring workflow.

```bash
/refactor "Split UserService into smaller, focused services"
```

**What it does:**
1. Review agent analyzes current code
2. QA agent ensures test coverage
3. Appropriate agent refactors incrementally
4. Tests run after each change
5. Review agent verifies improvements
6. Docs agent updates documentation

### /pr-review - Pull Request Review
Comprehensive multi-agent PR review.

```bash
/pr-review "https://github.com/bocopile/terraform-k8s-mac/pull/123"
```

**What it does:**
1. Fetches PR details from GitHub
2. Review agent checks code quality and security
3. QA agent reviews tests
4. Docs agent checks documentation
5. Specialized agents review their domains
6. Posts comprehensive review to GitHub

## MCP Integration

This configuration includes MCP (Model Context Protocol) servers for enhanced functionality:

### GitHub MCP
- Create and manage PRs
- Comment on issues and PRs
- Manage repository settings
- Fetch PR details

**Setup**: Add `GITHUB_TOKEN` to `.env`

### Slack MCP
- Send notifications
- Post to channels
- Manage messages

**Setup**: Add `SLACK_BOT_TOKEN` and `SLACK_TEAM_ID` to `.env`

### Memory MCP
- Store workflow patterns
- Learn from interactions
- Maintain context across sessions

**Setup**: Automatic, no configuration needed

### Sequential Thinking MCP
- Complex decision-making
- Multi-step reasoning
- Problem decomposition

**Setup**: Automatic, no configuration needed

## Hooks

### Approval Gate Hook
Triggers approval prompts for high-risk operations:
- Database migrations
- Production deployments
- Infrastructure changes
- Security-related changes

**Configuration**: Edit `.claude/hooks/approval-gate.sh`

### Workflow Notification Hook
Sends Slack notifications for workflow events:
- Workflow started
- Workflow completed
- Errors and warnings

**Configuration**: Set `SLACK_WEBHOOK_WORKFLOW` in `.env`

## Project-Specific Context

This is a **Terraform Kubernetes on Mac** project with the following characteristics:

- **Infrastructure**: Local Kubernetes cluster (Docker Desktop/Minikube)
- **IaC**: Terraform for provisioning
- **Services**: Various Kubernetes services deployed locally
- **Focus**: Local development environment setup

### DevOps Agent Optimizations
The DevOps agent is optimized for:
- Local Kubernetes operations
- Terraform module development
- Kubernetes manifest creation
- Local service deployment
- Ingress configuration for local domains

### Common Workflows

**Deploy a new service to local Kubernetes:**
```
/feature "Deploy Redis to Kubernetes with persistent storage"
```

**Update Terraform infrastructure:**
```
Use the devops-agent to add a new namespace for monitoring tools
```

**Audit security of Kubernetes manifests:**
```
Use the security-agent to review all Kubernetes manifests for security best practices
```

## Environment Variables

See `.env.example` for all available environment variables.

**Required:**
- `GITHUB_TOKEN` - For GitHub integration

**Recommended:**
- `JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN` - For JIRA integration
- `SLACK_BOT_TOKEN`, `SLACK_TEAM_ID` - For Slack notifications

**Optional:**
- Monitoring, registry, and other service credentials

## Best Practices

1. **Use workflow commands** for common tasks (`/feature`, `/bugfix`, etc.)
2. **Invoke specific agents** for specialized work
3. **Let the coordinator** handle complex multi-agent tasks
4. **Review changes** before committing
5. **Keep `.env` secure** - never commit it to git

## Troubleshooting

### MCP Servers Not Working
```bash
# Verify environment variables are loaded
echo $GITHUB_TOKEN
echo $SLACK_BOT_TOKEN

# Reload environment
export $(cat .env | xargs)
```

### Agents Not Found
```bash
# Verify agent files exist
ls -la .claude/agents/

# Check YAML frontmatter is valid
head -n 10 .claude/agents/coordinator.md
```

### Hooks Not Executing
```bash
# Make hooks executable
chmod +x .claude/hooks/*.sh

# Test hook directly
.claude/hooks/approval-gate.sh "Test task" "deployment" "high"
```

## Resources

- **Claude Code Docs**: https://docs.claude.com/en/docs/claude-code
- **MCP Documentation**: https://modelcontextprotocol.io/
- **GitHub**: https://github.com/bocopile/terraform-k8s-mac
- **JIRA**: https://gjrjr4545.atlassian.net/jira/software/projects/TERRAFORM/boards/67

## Contributing

To add new agents or commands:

1. Create new file in `.claude/agents/` or `.claude/commands/`
2. Follow the existing format with YAML frontmatter
3. Document the agent/command purpose and usage
4. Update this README

## License

This configuration is part of the terraform-k8s-mac project.
