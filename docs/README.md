# Midnight Village Documentation

## For New Developers

1. [Backend Quickstart](../backend/README.md) - Get the API running in 5 minutes
2. [Contributing Guide](contributing.md) - Development workflow and standards
3. [Architecture Overview](architecture.md) - Understand the system design

## Documentation Index

| Document | Description | Audience |
|----------|-------------|----------|
| [architecture.md](architecture.md) | Project structure, Django apps, settings, test organization | All developers |
| [api-patterns.md](api-patterns.md) | API conventions, error handling, URL patterns, serializers | Backend developers |
| [contributing.md](contributing.md) | Setup, code quality, git workflow, troubleshooting | All contributors |

## By Topic

### Getting Started
- [Backend Quickstart](../backend/README.md) - Minimal steps to run the API
- [Environment Setup](contributing.md#development-setup) - Full development environment

### Code Quality
- [Quality Checks](contributing.md#code-quality) - Linting, formatting, type checking
- [Pre-commit Hooks](contributing.md#before-committing) - Automated quality gates

### API Development
- [Response Format](api-patterns.md#response-format) - Success and error responses
- [Adding Endpoints](api-patterns.md#adding-a-new-endpoint) - Step-by-step guide
- [Exception Handling](api-patterns.md#exception-handling) - Error response patterns

### Testing
- [Test Organization](architecture.md#test-organization) - Unit, integration, contract tests
- [Running Tests](contributing.md#testing) - Commands and markers

### Project Structure
- [Directory Layout](architecture.md#directory-structure) - Where things live
- [Adding New Apps](architecture.md#adding-new-apps) - Creating Django apps

## Related Resources

- [Project README](../README.md) - Repository overview
- [Feature Specs](../specs/) - Detailed feature specifications
