# Ideaboard API

## Project Comprehensive Documentation
February 2025

## Project Overview

Our project aims to create a dual-purpose platform that bridges the gap between idea creators and developers seeking open-source projects to contribute to. The platform serves two primary functions: facilitating open-source project discovery and contribution while providing a space for incubating new project ideas.

## Current Project State

The project is positioned at the pre-development planning phase. We have completed the initial project definition and are preparing to begin MVP development. The technical stack has been chosen, and we have comprehensive implementation plans ready for both frontend and backend development.

## Technical Stack

The project will be built using:
- Backend: Ruby 3 and Rails (API-only mode)
- Frontend: React with Primer (GitHub's design system)
- Database: PostgreSQL
- Additional Technologies: Redis (for WebSocket support), GitHub API integration

## Core Features

### MVP Scope

The Minimum Viable Product encompasses:

GitHub Integration Features:
- OAuth-based authentication
- Repository data fetching (user info, project details, stars, forks, contributors, issues)
- Webhook implementation for real-time updates

Project Listing Requirements:
- Open-source license verification
- CONTRIBUTING.md file presence check
- Active open issues requirement
- Automatic language tag generation
- Support for community tags

Search and Discovery:
- Name-based search functionality
- Smart ranking algorithm considering:
  - Recent activity
  - Project popularity metrics
  - Contributor count
  - Open issues
  - Special consideration for new projects

Contribution System:
- Point-based system tracking merged pull requests
- User contribution leaderboard
- Project upvoting/downvoting system
- User reputation system (similar to gaming MMR)

### Post-MVP Features

Idea Platform:
- Idea submission system
- Discussion through comments
- GitHub project linking to original ideas
- Idea-to-project workflow

Enhanced Features:
- Achievement badges
- League system
- Social features
- Advanced project categorization

## Development Plans

We have created comprehensive development plans for both frontend and backend implementations. These plans are organized into phases and are available in separate documents:
- Frontend Development Plan (frontend-kanban.md)
- Backend Development Plan (backend-kanban.md)

## Technical Considerations

Several key technical aspects have been identified:

Real-time Updates:
- WebSocket implementation for live data
- Efficient update processing
- Client-side state management

Security:
- GitHub OAuth token management
- Rate limiting
- Input validation
- API security

Performance:
- Data caching strategy
- Database optimization
- API efficiency

Scalability:
- Webhook processing queue
- Background job management
- Database indexing strategy

## Project Goals

The platform aims to:
- Connect developers with meaningful projects
- Facilitate open-source contribution
- Provide space for idea incubation
- Maintain fair visibility for both new and established projects

## Current Challenges

Technical Challenges:
- Balancing project visibility in the ranking algorithm
- Implementing efficient real-time updates
- Managing GitHub API rate limits
- Ensuring scalable webhook processing

Community Challenges:
- Ensuring quality of listed projects
- Maintaining active project listings
- Preventing spam and misuse
- Encouraging meaningful contributions

## Design System Decision

The project will utilize Primer, GitHub's design system, for the frontend implementation. This decision was made to:
- Maintain consistency with familiar GitHub patterns
- Leverage pre-built components optimized for developer experiences
- Ensure accessibility and responsive design
- Provide a professional and established look and feel

## Development Context

The project owner's technical background influences the development approach:
- Professional experience with Ruby 3 & Rails
- Familiar with Python and Django
- Basic comprehension of Rust
- Primary expertise in backend development
- Learning frontend development through this project

## Next Steps

The immediate next steps are:
1. Setting up the development environment
2. Creating the basic project structure
3. Implementing the GitHub OAuth integration
4. Building the foundation for the project listing system

## Open Source Status

The project itself will be open-source, accepting contributions once the basic structure is established. This includes:
- MIT License
- Contribution guidelines
- Code of conduct
- Documentation requirements
- Issue templates
- Pull request templates

## Implementation Guide Status

A detailed implementation guide has been created, breaking down the MVP development into six main phases:
1. Foundation Setup
2. Authentication System
3. GitHub Integration
4. Project Listing System
5. Search and Discovery
6. Contribution Tracking

This documentation serves as a comprehensive overview of the project's current state and planned development approach. It can be used as a reference point for future discussions and development decisions.
