---
description: Fix a bug through systematic analysis, reproduction, fixing, testing, and verification
---

# Bug Fix Workflow

You are executing a comprehensive bug fix workflow that ensures the issue is properly understood, fixed, tested, and verified.

## Task Overview

The user has reported a bug: {user_request}

## Execution Plan

Use the **coordinator** agent to orchestrate this bug fix workflow:

### Phase 1: Bug Analysis & Reproduction (QA Agent)
1. Launch **qa-agent** to:
   - Analyze the bug description
   - Identify steps to reproduce
   - Determine affected components
   - Create a failing test that reproduces the bug
   - Assess bug severity and scope
   - Document the bug behavior

### Phase 2: Root Cause Investigation
1. Launch appropriate agent based on bug location:
   - **backend-agent** for API/database/infrastructure bugs
   - **frontend-agent** for UI/client-side bugs

2. Agent should:
   - Analyze the code to find root cause
   - Review related code and dependencies
   - Identify why the bug occurs
   - Determine impact on other features
   - Plan the fix approach

### Phase 3: Implementation
1. The same agent (backend or frontend) should:
   - Implement the fix
   - Ensure fix is minimal and focused
   - Avoid introducing new issues
   - Add defensive code if appropriate
   - Update any related code

### Phase 4: Testing
1. Launch **qa-agent** to:
   - Verify the original failing test now passes
   - Add regression tests to prevent recurrence
   - Test edge cases related to the bug
   - Verify no new issues were introduced
   - Check test coverage for the fixed code

### Phase 5: Code Review
1. Launch **review-agent** to:
   - Review the fix for correctness
   - Check for potential side effects
   - Verify the fix doesn't introduce security issues
   - Ensure the fix follows best practices
   - Validate that tests are adequate

### Phase 6: Documentation
1. Launch **docs-agent** to:
   - Document the bug and fix in code comments if needed
   - Update any relevant documentation
   - Add troubleshooting entry if user-facing
   - Update changelog if maintained

### Phase 7: Finalization
1. Verify all tests pass
2. Create GitHub PR with bug description and fix
3. Update JIRA ticket status (if configured)
4. Send notification via Slack (if configured)

## Guidelines

### For the Coordinator
- **Use TodoWrite** to track the bug fix process
- **Start with reproduction** - don't fix until bug is confirmed
- **Keep fix focused** - don't combine with refactoring
- **Ensure testing** - must have regression tests
- **Validate thoroughly** - verify no side effects

### Bug Severity Assessment
- **Critical**: Data loss, security vulnerability, system crash
- **High**: Major feature broken, affects many users
- **Medium**: Feature partially broken, workaround exists
- **Low**: Minor issue, cosmetic problem

### Testing Requirements
- Must have a test that reproduces the original bug
- Must have regression tests to prevent recurrence
- Must verify related functionality still works
- Should test edge cases around the bug

### Communication
- Explain root cause clearly
- Document why the bug occurred
- Note if similar bugs might exist elsewhere
- Highlight any preventive measures taken

## Bug Fix Patterns

### Data Validation Bug
1. QA agent reproduces with invalid data
2. Backend agent adds proper validation
3. QA agent tests various invalid inputs
4. Review agent verifies security implications

### UI Rendering Bug
1. QA agent reproduces visual issue
2. Frontend agent fixes rendering logic
3. QA agent tests in different browsers/sizes
4. Review agent checks performance impact

### API Bug
1. QA agent creates failing API test
2. Backend agent fixes API logic
3. QA agent tests API edge cases
4. Review agent validates error handling

### Database Bug
1. QA agent reproduces data issue
2. Backend agent fixes query/logic
3. QA agent tests with various data scenarios
4. Review agent checks for data integrity

## Approval Gates

Request user approval before:
- Fixing bugs that require database migrations
- Making changes to production configurations
- Implementing fixes that change API contracts
- Deploying hotfixes to production

## Success Criteria

The bug fix is complete when:
- [ ] Bug is reproduced with a failing test
- [ ] Root cause is identified and understood
- [ ] Fix is implemented correctly
- [ ] Original failing test now passes
- [ ] Regression tests are added
- [ ] All existing tests still pass
- [ ] Code review is complete
- [ ] Documentation is updated
- [ ] No new issues introduced
- [ ] PR is created (if applicable)

## Example Usage

```
/bugfix "Login fails when email contains special characters"
```

This will orchestrate:
1. QA: Reproduce with test using special characters in email
2. Backend: Fix email validation logic
3. QA: Test various special character combinations
4. Review: Check for similar issues in other validators
5. Docs: Update API documentation with email format requirements
6. Create PR with bug fix and tests

## Special Cases

### Regression Bugs
- Review when the bug was introduced
- Check why existing tests didn't catch it
- Improve test coverage to prevent similar issues

### Performance Bugs
- Profile to identify bottleneck
- Measure performance before and after fix
- Verify fix doesn't impact other operations

### Security Bugs
- Assess security impact immediately
- Prioritize fix based on severity
- Consider if emergency deployment needed
- Document security considerations

### Infrastructure Bugs
- Check Kubernetes configurations
- Verify Terraform state
- Test in staging before production
- Have rollback plan ready

## Important Notes

- Always create a test that reproduces the bug first
- Keep the fix minimal and focused
- Don't refactor while fixing bugs
- Ensure regression tests prevent recurrence
- Consider if similar bugs exist elsewhere

Start by having the coordinator analyze the bug and create a systematic approach to fix it.
