# IdeaBoard API

## Initial Problem

The thoughest challenge for a developer willing to contribute to open-source projects is to find ones that are interesting to them. The second toughest challenge is to find something worth contributing in those projects. The third one is to actually make contributions.

From that, I decided to write a little something to help me find projects I'd love contributing to, and iteration after iteration I've added multiple features just for fun and to explore technologies.

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
- **Testing**: RSpec tests + SimpleCov to ensure high coverage (95%+) of the project


## Available and working Features

### GitHub Integration
*I wanted to have a single and easy way to login without having to store sensitive data on my end. Also, I wanted the users to have a one-click button to be able to use the API.*

- OAuth-based authentication and user management
- GraphQL client for efficient repository data fetching
- Intelligent token rotation and rate limit management
- Repository qualification validation (license, CONTRIBUTING.md)

### Project Discovery and Qualification
 *Users can add any repository, theirs or others, and they will get processed and available to be discovered. But for the repository to be considered for the scoring system, it must have a `README.md`, `CONTRIBUTING.md` and a valid License.*
 
- Ranking algorithm incorporating activity, popularity, and contribution metrics
- Advanced search functionality with tag-based filtering
- Language and technology classification
- Repository health assessment
- Trending and featured project recommendations
- Repository qualification validation

### Contribution Tracking and Scoring
*Depending on the kind of the contribution, it has its own tracking and scoring logic. Merging a PR with an issue associated to it scores a lot of points, so does a long streak of daily contributions, first contribution to a repo earns points based on the ranking and the fame of said repo, etc ...*

- Pull request and issue monitoring
- Point-based reputation system
- Contribution streak calculation

### User Reputation System
*From those contributions, a user score is calculated and a ranking can then be generated, and this ranking can be filtered by repo, datespan, contribution type etc...*

- User activity and contribution metrics
- Repository-specific user statistics
- Detailed analytics for both users and repositories

### Sidekiq Workers and Webhooks Integration
*Repos are fetched depending on the owner's contribution type. TLDR, if the owner gives the appropriate rights, the data fetched from the repo is almost real-time through webhooks calls. Otherwise, it's based on Sidekiq workers which are being run multiple times a day, and update data accordingly. Also, there's a "Contribution" mode where users can opt-in to help updating others' repos by automatically authorizing us to use their Github token to fetch their data.*

- Sidekiq Workers ran periodically to fetch data
- Three-tier repository update strategy (owner, contributor, global pools) to fetch Repository Data
- Webhook integration for real-time updates

### Comprehensive REST API + Swagger doc
*The API follows the REST standards and has a swagger-doc available for anyone to explore*

- RESTful API with full Swagger/OpenAPI documentation available at `/api-docs`
- Authentication endpoints for GitHub OAuth flow
- Repository endpoints for discovery and management
- User endpoints for profile and contribution tracking
- Analytics endpoints for user and repository statistics
