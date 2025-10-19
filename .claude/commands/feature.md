---
description: Develop a complete feature from scratch, coordinating frontend, backend, testing, documentation, and review processes
---

# Feature Development Workflow

You are executing a comprehensive feature development workflow that orchestrates multiple specialized agents to deliver a complete, production-ready feature.

## Task Overview

The user has requested development of a new feature: {user_request}

## Execution Plan

Use the **coordinator** agent to orchestrate this multi-agent workflow:

### Phase 1: Planning & Analysis (Coordinator)
1. Analyze the feature requirements thoroughly
2. Break down into specific frontend, backend, and infrastructure tasks
3. Create a comprehensive task list using TodoWrite
4. Identify potential risks and dependencies
5. Determine if approval is needed for any steps

### Phase 2: Backend Development
1. Launch **backend-agent** to:
   - Design and implement API endpoints
   - Create/update database schemas
   - Implement business logic
   - Set up necessary Kubernetes resources
   - Add appropriate logging and error handling

### Phase 3: Frontend Development
1. Launch **frontend-agent** to:
   - Create UI components
   - Implement client-side logic
   - Integrate with backend APIs
   - Ensure responsive design
   - Add proper error handling and loading states

### Phase 4: Testing
1. Launch **qa-agent** to:
   - Create unit tests for backend logic
   - Create unit tests for frontend components
   - Develop integration tests for API endpoints
   - Create E2E tests for critical user flows
   - Verify test coverage meets standards (80%+)

### Phase 5: Documentation
1. Launch **docs-agent** to:
   - Document API endpoints
   - Update README if needed
   - Add code comments for complex logic
   - Create user documentation if needed
   - Provide usage examples

### Phase 6: Code Review
1. Launch **review-agent** to:
   - Review all code changes for quality
   - Check for security vulnerabilities
   - Verify performance considerations
   - Ensure best practices are followed
   - Validate test coverage and quality

### Phase 7: Integration & Finalization
1. Verify all components work together
2. Run all tests and ensure they pass
3. Create a GitHub pull request (if in a git repo)
4. Update any related JIRA issues (if configured)
5. Send completion notification via Slack (if configured)

## Guidelines

### For the Coordinator
- **Use TodoWrite** to track all tasks and subtasks
- **Run agents in parallel** when tasks are independent (backend + frontend can run concurrently)
- **Validate outputs** from each agent before proceeding
- **Handle errors gracefully** and retry with adjusted approaches if needed
- **Keep user informed** of major milestones

### Agent Communication
- Provide clear, specific instructions to each agent
- Include necessary context (tech stack, conventions, etc.)
- Specify deliverables and acceptance criteria
- Request progress updates for long-running tasks

### Quality Standards
- All code must have tests with 80%+ coverage
- Security best practices must be followed
- Performance considerations must be addressed
- Documentation must be complete and accurate
- Code must pass review before completion

### Integration Points
- Backend and frontend must have compatible APIs
- Tests must cover integration points
- Documentation must reflect actual implementation
- All changes must be cohesive

## MCP Integration Opportunities

If configured, leverage these integrations:

- **GitHub**: Create PR automatically when complete
- **JIRA**: Update issue status, add comments
- **Slack**: Notify team of progress and completion
- **Memory Bank**: Store patterns for future reference

## Approval Gates

The coordinator should request user approval before:
- Making database schema changes
- Modifying infrastructure configurations
- Making breaking API changes
- Deploying to production environments

## Success Criteria

The feature is complete when:
- [ ] Backend API is implemented and tested
- [ ] Frontend UI is implemented and functional
- [ ] All tests pass (unit, integration, E2E)
- [ ] Test coverage meets 80%+ standard
- [ ] Code review is complete with no blockers
- [ ] Documentation is complete and accurate
- [ ] All components integrate successfully
- [ ] PR is created (if applicable)

## Example Usage

```
/feature "Add user profile page with avatar upload"
```

This will orchestrate:
1. Backend: User profile API endpoint, avatar storage integration
2. Frontend: Profile page component, avatar upload UI
3. Testing: API tests, component tests, E2E flow tests
4. Documentation: API endpoint docs, component usage guide
5. Review: Security check (file upload validation), performance review
6. Integration: Create PR with all changes

## Important Notes

- The coordinator should handle the orchestration
- Multiple agents can work in parallel
- Each agent should focus on their specialty
- Integration happens at the end
- User approval may be required for certain operations

Start by having the coordinator create a detailed execution plan with TodoWrite, then systematically execute each phase.
