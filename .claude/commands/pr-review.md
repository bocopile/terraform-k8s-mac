---
description: Conduct comprehensive pull request review covering code quality, security, performance, testing, and documentation
---

# Pull Request Review Workflow

You are executing a comprehensive PR review workflow that ensures code quality, security, and maintainability.

## Task Overview

The user has requested PR review: {user_request}

Expected input: GitHub PR URL or PR number

## Execution Plan

Use the **coordinator** agent to orchestrate this PR review workflow:

### Phase 1: PR Information Gathering (Coordinator)
1. Fetch PR details using GitHub MCP or gh CLI:
   - PR title and description
   - Changed files
   - Commits
   - Linked issues
   - Current status
   - Test results

2. Analyze scope:
   - Identify affected components
   - Determine review depth needed
   - Assign appropriate specialist agents

### Phase 2: Code Quality Review (Review Agent)
1. Launch **review-agent** to:
   - Review code for quality and maintainability
   - Check naming conventions
   - Verify code organization
   - Identify code smells
   - Check for duplication
   - Verify error handling
   - Validate logging
   - Check complexity

### Phase 3: Security Review (Review Agent)
1. **review-agent** should specifically check:
   - Input validation
   - SQL injection vulnerabilities
   - XSS vulnerabilities
   - Authentication/authorization
   - Sensitive data exposure
   - Dependency vulnerabilities
   - Secrets in code
   - CSRF protection

### Phase 4: Performance Review (Review Agent)
1. **review-agent** should analyze:
   - Algorithm efficiency
   - Database query optimization
   - Caching strategies
   - Memory usage
   - N+1 query problems
   - Async operation usage
   - Resource cleanup

### Phase 5: Testing Review (QA Agent)
1. Launch **qa-agent** to:
   - Review test coverage
   - Check test quality
   - Verify edge cases tested
   - Review test organization
   - Check for brittle tests
   - Verify integration tests
   - Check E2E test coverage

### Phase 6: Documentation Review (Docs Agent)
1. Launch **docs-agent** to:
   - Check code comments
   - Verify API documentation
   - Review README updates
   - Check example accuracy
   - Verify changelog updates
   - Check migration guides

### Phase 7: Specialized Reviews

#### For Backend Changes (Backend Agent)
Launch **backend-agent** to review:
- API design and consistency
- Database schema changes
- Migration scripts
- Kubernetes configurations
- Infrastructure changes
- Service integrations

#### For Frontend Changes (Frontend Agent)
Launch **frontend-agent** to review:
- Component design
- State management
- Accessibility
- Responsive design
- Browser compatibility
- Performance (re-renders)

### Phase 8: Integration Review (Coordinator)
1. Verify changes work together:
   - Frontend-backend integration
   - Database changes compatibility
   - Infrastructure impacts
   - Dependency conflicts
   - Breaking changes handled

### Phase 9: Review Summary & Feedback
1. Compile findings from all agents
2. Categorize by severity:
   - Critical (must fix)
   - High (should fix)
   - Medium (consider fixing)
   - Low (optional)
3. Provide constructive feedback
4. Post review comments to GitHub PR

## Review Checklist

### Code Quality
- [ ] Code is readable and well-organized
- [ ] Naming is clear and consistent
- [ ] Functions are appropriately sized
- [ ] No code duplication (DRY)
- [ ] Proper error handling
- [ ] Appropriate logging
- [ ] No commented-out code
- [ ] No hardcoded values

### Security
- [ ] Input validation implemented
- [ ] No SQL injection risks
- [ ] No XSS vulnerabilities
- [ ] Authentication checked
- [ ] Authorization verified
- [ ] Secrets not exposed
- [ ] Dependencies secure
- [ ] HTTPS used

### Performance
- [ ] Efficient algorithms
- [ ] Optimized queries
- [ ] Appropriate caching
- [ ] No N+1 queries
- [ ] Async where appropriate
- [ ] Resources cleaned up
- [ ] No memory leaks

### Testing
- [ ] Test coverage ≥ 80%
- [ ] Tests are meaningful
- [ ] Edge cases covered
- [ ] Integration tests present
- [ ] E2E tests for critical flows
- [ ] Tests are maintainable
- [ ] All tests pass

### Documentation
- [ ] Code comments for complex logic
- [ ] API documented
- [ ] README updated
- [ ] Examples provided
- [ ] Changelog updated
- [ ] Migration guide (if needed)

### Architecture
- [ ] Follows project patterns
- [ ] Separation of concerns
- [ ] Design patterns appropriate
- [ ] Scalable design
- [ ] Maintainable structure

### Infrastructure (if applicable)
- [ ] Kubernetes manifests valid
- [ ] Resource limits set
- [ ] Health checks configured
- [ ] Secrets properly handled
- [ ] Terraform changes valid

## Review Severity Levels

### Critical (🔴 Must Fix Before Merge)
- Security vulnerabilities
- Data loss risks
- Breaking changes without migration
- Critical bugs
- Test failures

### High (🟡 Should Fix Before Merge)
- Significant code quality issues
- Performance problems
- Missing tests for critical paths
- Poor error handling
- Incomplete documentation

### Medium (🟢 Consider Fixing)
- Code clarity improvements
- Minor performance optimizations
- Missing edge case tests
- Documentation gaps
- Style inconsistencies

### Low (⚪ Optional)
- Nitpicks and preferences
- Minor refactoring opportunities
- Additional test coverage
- Documentation enhancements

## Feedback Template

```markdown
## PR Review Summary

### Overview
[Brief summary of what this PR does]

### 🔴 Critical Issues (Must Fix)
1. [Issue with explanation and suggestion]

### 🟡 High Priority (Should Fix)
1. [Issue with explanation and suggestion]

### 🟢 Medium Priority (Consider)
1. [Issue with explanation and suggestion]

### ⚪ Low Priority (Optional)
1. [Suggestion for improvement]

### ✅ Positive Highlights
1. [Things done well]

### 📊 Metrics
- Test Coverage: X%
- Files Changed: X
- Lines Added/Removed: +X/-Y
- Complexity: [Assessment]

### 🎯 Recommendation
- [ ] Approve
- [ ] Request Changes
- [ ] Comment/Discussion Needed

### 📝 Additional Notes
[Any other relevant information]
```

## MCP Integration

If GitHub MCP is configured:
- Fetch PR details automatically
- Post review comments directly
- Request changes or approve
- Add reviewers
- Update labels

## Example Usage

```
/pr-review "https://github.com/org/repo/pull/123"
```

Or:

```
/pr-review "123"
```

This will orchestrate:
1. Fetch PR details from GitHub
2. Review code quality and security
3. Check test coverage and quality
4. Verify documentation
5. Specialized reviews (frontend/backend)
6. Compile comprehensive feedback
7. Post review to GitHub

## Guidelines

### For the Coordinator
- **Use TodoWrite** to track review steps
- **Parallel reviews** when possible (code quality + security + tests)
- **Compile feedback** from all agents
- **Categorize by severity**
- **Be constructive** in feedback

### Providing Feedback
- Be specific with examples
- Explain the "why" behind suggestions
- Provide code examples for fixes
- Link to documentation/resources
- Acknowledge good practices
- Be respectful and professional

### Communication Style
```markdown
❌ Bad: "This is wrong"
✅ Good: "This approach has a security risk. Consider using parameterized queries to prevent SQL injection. Example: [code]"

❌ Bad: "Rewrite this"
✅ Good: "This function handles multiple responsibilities. Consider extracting into smaller functions for better testability: [suggestions]"
```

## Special Review Cases

### Database Migrations
- Check migration up/down scripts
- Verify data preservation
- Check for breaking changes
- Validate rollback plan

### Breaking Changes
- Verify deprecation notices
- Check migration guide
- Validate version bump
- Ensure backward compatibility plan

### Performance Changes
- Request benchmarks
- Compare before/after metrics
- Check for regressions
- Verify optimization claims

### Security Changes
- Extra scrutiny required
- Verify security best practices
- Check for side effects
- Consider security team review

## Success Criteria

PR review is complete when:
- [ ] All code reviewed by appropriate agents
- [ ] Security checked thoroughly
- [ ] Performance analyzed
- [ ] Tests reviewed and adequate
- [ ] Documentation verified
- [ ] Feedback compiled and categorized
- [ ] Review posted to GitHub (if applicable)
- [ ] Recommendation provided (approve/request changes)

## Important Notes

- Focus on the code, not the person
- Be constructive and helpful
- Provide actionable feedback
- Acknowledge good practices
- Consider time/effort vs. benefit
- Balance perfection with pragmatism

Start by having the coordinator fetch PR details and delegate reviews to appropriate specialized agents.
