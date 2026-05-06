# Insforge

This folder contains documentation for Insforge.

## Overview

Insforge is the application layer in this setup. Use this folder to document the business logic, workflows, services, and user-facing features.

## Suggested contents

- Project structure
- Configuration and environment variables
- Main features and workflows
- API routes or service methods
- Development and deployment notes

## Example outline

1. Overview
2. Installation
3. Configuration
4. Development workflow
5. Common tasks
6. Deployment

## Self-hosted Docker

Use this flow to run Insforge on a machine with Docker and Docker Compose installed.

1. Clone the repository.

	```bash
	git clone https://github.com/insforge/insforge.git
	cd insforge
	```

2. Create the environment file.

	```bash
	cp .env.example .env
	```

3. Start the stack.

	```bash
	docker compose up
	```