# Kubernetes Zero to Hero - Progress Makefile
# Track progress with simple commands

.PHONY: help status start complete list next stats setup

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

help: ## Show this help message
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║  Kubernetes Zero to Hero - Progress Tracker           ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Quick Commands:"
	@echo "  make status          Show current progress"
	@echo "  make start CH=1      Start Chapter 1"
	@echo "  make complete CH=1   Complete Chapter 1"
	@echo "  make next            Show what to do next"
	@echo "  make stats           Show statistics"
	@echo "  make setup           Setup progress tracking"
	@echo ""
	@echo "Chapter Commands:"
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		echo "  make ch$$i           Start/Show Chapter $$i"; \
	done
	@echo ""

setup: ## Initialize progress tracking
	@git config --local alias.progress '!git log --oneline --grep="progress:"'
	@echo "$(GREEN)✓ Progress tracking initialized$(NC)"
	@echo "Run: make status"

status: ## Show current progress
	@echo ""
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║  📊 Your Progress                                      ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@git tag -l "progress-*" 2>/dev/null | sort -V | tail -5 || echo "No progress yet. Run: make start CH=1"
	@echo ""
	@$(MAKE) --no-print-directory show-progress

show-progress:
	@COMPLETED=$$(git tag -l "progress-ch*" 2>/dev/null | wc -l); \
	if [ $$COMPLETED -eq 0 ]; then \
		echo "$(YELLOW)⬜ Not started yet$(NC)"; \
		echo ""; \
		echo "Start with: make start CH=1"; \
	elif [ $$COMPLETED -eq 10 ]; then \
		echo "$(GREEN)🎉 ALL CHAPTERS COMPLETE!$(NC)"; \
		echo "$(GREEN)   $$COMPLETED/10 chapters done$(NC)"; \
	else \
		echo "Progress: $(GREEN)$$COMPLETED/10$(NC) chapters"; \
		$(MAKE) --no-print-directory progress-bar; \
	fi

progress-bar:
	@COMPLETED=$$(git tag -l "progress-ch*" 2>/dev/null | wc -l); \
	PERCENT=$$((COMPLETED * 100 / 10)); \
	FILLED=$$((COMPLETED * 20 / 10)); \
	EMPTY=$$((20 - FILLED)); \
	BAR=$$(printf '%*s' "$$FILLED" | tr ' ' '█'); \
	BAR_EMPTY=$$(printf '%*s' "$$EMPTY" | tr ' ' '░'); \
	echo "[$$BAR$$BAR_EMPTY] $$PERCENT%"; \
	echo ""

start: ## Start a chapter (Usage: make start CH=1)
	@if [ -z "$(CH)" ]; then \
		echo "$(RED)Error: Please specify chapter$(NC)"; \
		echo "Usage: make start CH=1"; \
		exit 1; \
	fi
	@echo "$(YELLOW)🟡 Starting Chapter $(CH)...$(NC)"
	@git tag -f "progress-ch$(CH)-started" $$(git rev-parse HEAD) 2>/dev/null || true
	@echo "$(GREEN)✓ Marked Chapter $(CH) as started$(NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Read: cat chapter-0$(CH)/README.md"
	@echo "  2. Practice: cat chapter-0$(CH)/LABS.md"
	@echo "  3. Review: cat chapter-0$(CH)/INTERVIEW.md"
	@echo ""
	@echo "When done: make complete CH=$(CH)"

complete: ## Complete a chapter (Usage: make complete CH=1)
	@if [ -z "$(CH)" ]; then \
		echo "$(RED)Error: Please specify chapter$(NC)"; \
		echo "Usage: make complete CH=1"; \
		exit 1; \
	fi
	@echo "$(GREEN)✅ Completing Chapter $(CH)...$(NC)"
	@git tag -f "progress-ch$(CH)" $$(git rev-parse HEAD) 2>/dev/null || true
	@git tag -d "progress-ch$(CH)-started" 2>/dev/null || true
	@echo "$(GREEN)✓ Chapter $(CH) complete!$(NC)"
	@echo ""
	@$(MAKE) --no-print-directory show-progress
	@echo ""
	@NEXT=$$((CH + 1)); \
	if [ $$NEXT -le 10 ]; then \
		echo "Next: make start CH=$$NEXT"; \
	else \
		echo "🎉 Congratulations! You've completed all chapters!"; \
	fi

# Shortcut commands for each chapter
ch1: ; @$(MAKE) start CH=1
ch2: ; @$(MAKE) start CH=2
ch3: ; @$(MAKE) start CH=3
ch4: ; @$(MAKE) start CH=4
ch5: ; @$(MAKE) start CH=5
ch6: ; @$(MAKE) start CH=6
ch7: ; @$(MAKE) start CH=7
ch8: ; @$(MAKE) start CH=8
ch9: ; @$(MAKE) start CH=9
ch10: ; @$(MAKE) start CH=10

next: ## Show what to do next
	@echo ""
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║  📋 Recommended Next Steps                             ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		if ! git tag -l "progress-ch$$i" | grep -q "progress"; then \
			echo "$(YELLOW)➡️  Chapter $$i$(NC)"; \
			echo "   Run: make start CH=$$i"; \
			echo ""; \
			exit 0; \
		fi; \
	done
	@echo "$(GREEN)🎉 All chapters complete!$(NC)"

list: ## List all chapters with status
	@echo ""
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║  📚 Chapter Status                                     ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		CHP=$$(printf "%02d" $$i); \
		if git tag -l "progress-ch$$i" | grep -q "progress"; then \
			echo "$(GREEN)✅ Chapter $$i - COMPLETE$(NC)"; \
		elif git tag -l "progress-ch$$i-started" | grep -q "progress"; then \
			echo "$(YELLOW)🟡 Chapter $$i - IN PROGRESS$(NC)"; \
		else \
			echo "$(RED)⬜ Chapter $$i - NOT STARTED$(NC)"; \
		fi; \
	done
	@echo ""

stats: ## Show detailed statistics
	@echo ""
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║  📈 Study Statistics                                   ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@COMPLETED=$$(git tag -l "progress-ch*" | grep -v started | wc -l); \
	STARTED=$$(git tag -l "progress-ch*-started" | wc -l); \
	NOT_STARTED=$$((10 - COMPLETED)); \
	PERCENT=$$((COMPLETED * 100 / 10)); \
	echo "Completed:   $(GREEN)$$COMPLETED/10$(NC)"; \
	echo "In Progress: $(YELLOW)$$STARTED$(NC)"; \
	echo "Not Started: $(RED)$$NOT_STARTED$(NC)"; \
	echo "Percentage:  $$PERCENT%"; \
	echo ""

reset: ## Reset all progress (DANGER)
	@echo "$(RED)⚠️  This will delete all progress tags!$(NC)"
	@read -p "Are you sure? [y/N] " confirm && [ $$confirm = y ] && \
		git tag -l "progress-*" | xargs git tag -d && \
		echo "$(GREEN)Progress reset$(NC)" || \
		echo "Cancelled"

push-progress: ## Push progress tags to remote
	@git push origin --tags
	@echo "$(GREEN)✓ Progress synced to GitHub$(NC)"

pull-progress: ## Pull progress tags from remote
	@git pull origin --tags
	@echo "$(GREEN)✓ Progress synced from GitHub$(NC)"

# Lab completion shortcuts
lab-complete: ## Mark a lab complete (Usage: make lab-complete CH=1 LAB=1)
	@if [ -z "$(CH)" ] || [ -z "$(LAB)" ]; then \
		echo "$(RED)Error: Please specify chapter and lab$(NC)"; \
		echo "Usage: make lab-complete CH=1 LAB=1"; \
		exit 1; \
	fi
	@git tag -f "progress-ch$(CH)-lab$(LAB)" $$(git rev-parse HEAD) 2>/dev/null || true
	@echo "$(GREEN)✓ Chapter $(CH) Lab $(LAB) complete$(NC)"
