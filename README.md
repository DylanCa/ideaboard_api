# IdeaBoard API - Couldn't find a better name

IdeaBoard is a platform for discovering and contributing to open-source projects on GitHub with a scoring system.

## Overview

IdeaBoard serves as a gamified service where developers can find open-source projects aligned with their skills and interests, and score points for each opensource contribution they have made. The platform features a ranking and recommendation system that highlight projects needing attention or matching a developer's needs.

The core mission is to create an ecosystem that lowers the barrier to open-source contribution by connecting developers with projects.

## Architecture

IdeaBoard is built on the technology stack:

- **Backend**: Ruby on Rails 8.0 in API mode
- **Database**: PostgreSQL
- **Authentication**: GitHub OAuth with secure JWT token management
- **GitHub Integration**: GraphQL-based API client with sophisticated rate limiting
- **Background Processing**: Sidekiq with tiered repository update system
- **Real-time Updates**: Webhook handling for repository events
- **Caching**: Redis for performance optimization

## Key Features

### GitHub Integration

- OAuth-based authentication and user management
- GraphQL client for efficient repository data fetching
- Intelligent token rotation and rate limit management
- Three-tier repository update strategy (owner, contributor, global pools)
- Webhook integration for real-time updates
- Repository qualification validation (license, CONTRIBUTING.md)

### Project Discovery

- Ranking algorithm incorporating activity, popularity, and contribution metrics
- Advanced search functionality with tag-based filtering
- Language and technology classification
- Repository health assessment
- Trending and featured project recommendations
- Repository qualification validation

### Contribution Tracking

- Pull request and issue monitoring
- Point-based reputation system
- User activity and contribution metrics
- Contribution streak calculation
- Repository-specific user statistics
- Detailed analytics for both users and repositories

### REST API

- RESTful API with full Swagger/OpenAPI documentation available at `/api-docs`
- Authentication endpoints for GitHub OAuth flow
- Repository endpoints for discovery and management
- User endpoints for profile and contribution tracking
- Analytics endpoints for user and repository statistics
- Webhook endpoints for GitHub event integration


## Current Features

IdeaBoard currently implements:

- GitHub OAuth authentication
- Repository discovery and qualification
- Contribution tracking and scoring
- User reputation system
- Advanced search and filtering
- Webhook integration
- Comprehensive REST API
