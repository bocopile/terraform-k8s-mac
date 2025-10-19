---
description: Safely refactor code to improve quality, performance, or maintainability while ensuring functionality remains intact
---

# Refactoring Workflow

You are executing a safe and systematic refactoring workflow that improves code quality while maintaining functionality.

## Task Overview

The user has requested refactoring: {user_request}

## Execution Plan

Use the **coordinator** agent to orchestrate this refactoring workflow:

### Phase 1: Analysis & Planning (Review Agent)
1. Launch **review-agent** to:
   - Analyze current code structure
   - Identify specific issues to address
   - Assess code quality metrics
   - Determine refactoring scope
   - Identify potential risks
   - Create refactoring plan

### Phase 2: Establish Safety Net (QA Agent)
1. Launch **qa-agent** to:
   - Review existing test coverage
   - Add missing tests if coverage is low (<80%)
   - Create baseline test suite
   - Document current behavior
   - Verify all tests pass before refactoring

### Phase 3: Incremental Refactoring
1. Launch appropriate agent based on code type:
   - **backend-agent** for backend code
   - **frontend-agent** for frontend code

2. Agent should refactor in small, safe steps:
   - Make one focused change at a time
   - Run tests after each change
   - Commit each successful step
   - Roll back if tests fail
   - Keep changes reviewable

### Phase 4: Continuous Verification (QA Agent)
1. **qa-agent** should verify after each refactoring step:
   - All existing tests still pass
   - No new bugs introduced
   - Behavior remains unchanged
   - Performance is not degraded

### Phase 5: Enhancement Testing (QA Agent)
1. Launch **qa-agent** to:
   - Add tests for improved code paths
   - Verify edge cases still work
   - Test error handling
   - Measure performance improvements
   - Update test documentation

### Phase 6: Quality Review
1. Launch **review-agent** to:
   - Verify refactoring goals achieved
   - Check code quality improvements
   - Ensure best practices followed
   - Validate no issues introduced
   - Measure complexity reduction

### Phase 7: Documentation Update
1. Launch **docs-agent** to:
   - Update code comments if needed
   - Revise documentation for changed APIs
   - Document architectural improvements
   - Update examples if affected

### Phase 8: Finalization
1. Run full test suite
2. Verify all quality metrics improved
3. Create PR with clear refactoring description
4. Document what changed and why

## Guidelines

### For the Coordinator
- **Use TodoWrite** to track refactoring steps
- **Make incremental changes** - never refactor everything at once
- **Test continuously** - run tests after each change
- **Commit often** - each successful step should be committed
- **Rollback if needed** - revert if tests fail

### Refactoring Safety Principles
1. **Tests first**: Ensure good test coverage before refactoring
2. **Small steps**: Make tiny, verifiable changes
3. **Verify constantly**: Run tests after each change
4. **Commit incrementally**: Save each successful step
5. **No feature additions**: Refactor OR add features, never both

### Types of Refactoring

#### Code Structure
- Extract functions/methods
- Rename for clarity
- Remove duplication
- Simplify complex logic
- Improve organization

#### Performance
- Optimize algorithms
- Reduce database queries
- Improve caching
- Minimize re-renders (frontend)
- Optimize loops

#### Architecture
- Improve separation of concerns
- Apply design patterns
- Reduce coupling
- Increase cohesion
- Better error handling

#### Maintainability
- Improve readability
- Add comments
- Simplify configuration
- Reduce technical debt
- Update dependencies

## Refactoring Patterns

### Extract Function
```javascript
// Before: Long function with multiple responsibilities
function processOrder(order) {
  // 100 lines of code
}

// After: Extracted smaller functions
function processOrder(order) {
  validateOrder(order);
  calculateTotal(order);
  applyDiscounts(order);
  processPayment(order);
  sendConfirmation(order);
}
```

### Remove Duplication
```javascript
// Before: Duplicated logic
function getUserPosts(userId) {
  const user = await db.query('SELECT * FROM users WHERE id = ?', [userId]);
  return db.query('SELECT * FROM posts WHERE user_id = ?', [userId]);
}

function getUserComments(userId) {
  const user = await db.query('SELECT * FROM users WHERE id = ?', [userId]);
  return db.query('SELECT * FROM comments WHERE user_id = ?', [userId]);
}

// After: Extracted common logic
async function validateUser(userId) {
  return db.query('SELECT * FROM users WHERE id = ?', [userId]);
}

async function getUserPosts(userId) {
  await validateUser(userId);
  return db.query('SELECT * FROM posts WHERE user_id = ?', [userId]);
}
```

### Simplify Conditionals
```javascript
// Before: Complex nested conditions
if (user) {
  if (user.isActive) {
    if (user.hasPermission('write')) {
      // do something
    }
  }
}

// After: Guard clauses
if (!user) return;
if (!user.isActive) return;
if (!user.hasPermission('write')) return;
// do something
```

## Testing Strategy

### Before Refactoring
- Ensure test coverage ≥ 80%
- All tests passing
- Baseline performance metrics
- Document current behavior

### During Refactoring
- Run tests after each change
- Verify performance not degraded
- Check for new warnings/errors
- Validate behavior unchanged

### After Refactoring
- All tests still pass
- Coverage maintained or improved
- Performance same or better
- No new issues introduced

## Approval Gates

Request user approval before:
- Large-scale refactoring (>500 lines)
- Changing public APIs
- Database schema changes
- Refactoring critical paths
- Major architectural changes

## Success Criteria

The refactoring is complete when:
- [ ] Refactoring goals achieved
- [ ] All tests pass
- [ ] Test coverage maintained or improved
- [ ] Code quality metrics improved
- [ ] No functionality broken
- [ ] Performance maintained or improved
- [ ] Documentation updated
- [ ] Code review approved
- [ ] PR created with clear explanation

## Metrics to Track

### Code Quality
- Cyclomatic complexity (lower is better)
- Code duplication (lower is better)
- Function length (shorter is better)
- Test coverage (higher is better)

### Performance
- Response time
- Memory usage
- Database query count
- Render time (frontend)

## Example Usage

```
/refactor "Split UserService into smaller, focused services"
```

This will orchestrate:
1. Review: Analyze UserService, identify responsibilities
2. QA: Ensure UserService has good test coverage
3. Backend: Extract smaller services incrementally:
   - UserAuthService
   - UserProfileService
   - UserPreferencesService
4. QA: Verify tests pass after each extraction
5. Review: Verify separation of concerns improved
6. Docs: Update architecture documentation
7. Create PR with refactoring details

## Common Refactoring Tasks

### Backend Refactoring
- Extract business logic from controllers
- Simplify database queries
- Improve error handling
- Reduce code duplication
- Apply design patterns

### Frontend Refactoring
- Extract reusable components
- Simplify state management
- Reduce component complexity
- Improve prop drilling
- Optimize re-renders

### Infrastructure Refactoring
- Simplify Kubernetes manifests
- Organize Terraform modules
- Improve configuration management
- Standardize resource definitions

## Important Notes

- **Never refactor and add features simultaneously**
- **Always have tests before refactoring**
- **Make changes incrementally**
- **Commit after each successful step**
- **Be ready to rollback**
- **Document the "why" of refactoring**

## Rollback Plan

If refactoring causes issues:
1. Revert to last good commit
2. Analyze what went wrong
3. Adjust approach
4. Retry with smaller steps
5. Request help if stuck

Start by having the coordinator create a safe, incremental refactoring plan with the review agent analyzing the current code first.
