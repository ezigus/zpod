# Issues Directory

This directory contains detailed issue documentation for the zPod development project, following the new issue management standards established in [copilot-instructions.md](../.github/copilot-instructions.md).

## Issue Numbering System

### Standard Numbering
Issues are numbered in the order they should be completed (e.g., 01, 02, 03, etc.).

### Sub-Issue Numbering (xx.y Format)
When new issues are identified that need to be completed between existing issues, they use the `xx.y` format:
- **xx**: The preceding issue number
- **y**: The sub-issue sequence (1, 2, 3, etc.)

**Example**: If an issue is identified between Issue 17 and Issue 18:
- First sub-issue: `17.1`
- Second sub-issue: `17.2`
- Additional sub-issues: `17.3`, `17.4`, etc.

## Issue Documentation Format

Each issue file follows this naming convention:
```
xx.y-brief-description.md
```

### Required Sections
- **Priority**: High/Medium/Low priority level
- **Status**: 🔄 Planned, 🚧 In Progress, ✅ Completed, ⏸️ Blocked
- **Description**: Clear problem statement and goals
- **Acceptance Criteria**: Specific, measurable requirements
- **Implementation Approach**: High-level phases and steps
- **Specification References**: Links to relevant spec sections
- **Dependencies**: Other issues or components required
- **Estimated Effort**: Complexity and time estimation
- **Success Metrics**: How completion will be measured

## Current Issues

### Testing Framework Issues (12.x series)
- **12.2**: Testing Framework Refactoring ✅ Completed
- **12.3**: Performance Testing Patterns 🔄 Planned
- **12.4**: Automated Accessibility Testing 🔄 Planned  
- **12.5**: Cross-Platform Testing Support 🔄 Planned

## TODO Tag Integration

Issues in this directory correspond to TODO tags in the codebase:
- **Format**: `// TODO: [Issue #xx.y] Description`
- **Location**: Added where implementation should occur
- **Lifecycle**: Removed when issue is completed

## Specification Mapping

Issues map to specification sections in the `zpod/spec/` directory:
- Each issue references relevant specification sections
- Implementation should validate against spec requirements
- Tests should verify spec compliance

## Development Workflow

1. **Issue Identification**: Create new issue when work doesn't fit current scope
2. **Numbering**: Use appropriate xx.y format for sequencing
3. **Documentation**: Follow standard format with comprehensive details
4. **TODO Tags**: Add code comments linking to issues
5. **Implementation**: Follow TDD approach with spec validation
6. **Completion**: Remove TODO tags and update issue status

## Quality Gates

Before marking issues complete:
- [ ] All acceptance criteria met
- [ ] Related TODO tags removed
- [ ] Tests pass and provide adequate coverage
- [ ] Specification requirements validated
- [ ] Documentation updated

## Integration with Development Process

This issue management system integrates with:
- **dev-log**: Development progress tracking
- **spec**: Specification-driven development
- **testing**: Comprehensive test coverage
- **CI/CD**: Automated validation and quality gates

For detailed development guidelines, see [copilot-instructions.md](../.github/copilot-instructions.md).