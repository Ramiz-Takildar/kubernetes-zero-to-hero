#!/bin/bash
# Progress Tracker Script for Kubernetes Zero to Hero
# Usage: ./progress.sh [chapter] [section] [status]

PROGRESS_FILE="PROGRESS.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to show usage
show_usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  status              Show current progress summary"
    echo "  list                List all incomplete items"
    echo "  mark [ch] [sec]     Mark section as complete"
    echo "  stats               Show statistics"
    echo ""
    echo "Examples:"
    echo "  $0 status           # Show overall progress"
    echo "  $0 list             # Show what to do next"
    echo "  $0 mark 1 theory    # Mark Chapter 1 theory complete"
    echo ""
    echo "Sections: theory, interview, lab1, lab2, lab3, lab4, lab5"
}

# Show current status
show_status() {
    echo "📊 Kubernetes Zero to Hero - Progress Status"
    echo "=============================================="
    echo ""
    
    # Count completed items
    COMPLETED=$(grep -c "✅" $PROGRESS_FILE 2>/dev/null || echo "0")
    IN_PROGRESS=$(grep -c "🟡" $PROGRESS_FILE 2>/dev/null || echo "0")
    NOT_STARTED=$(grep -c "⬜" $PROGRESS_FILE 2>/dev/null || echo "0")
    TOTAL=$((COMPLETED + IN_PROGRESS + NOT_STARTED))
    
    if [ $TOTAL -gt 0 ]; then
        PERCENTAGE=$((COMPLETED * 100 / TOTAL))
    else
        PERCENTAGE=0
    fi
    
    echo "Overall Progress: $PERCENTAGE%"
    echo ""
    echo -e "${GREEN}✅ Completed:${NC}     $COMPLETED"
    echo -e "${YELLOW}🟡 In Progress:${NC}  $IN_PROGRESS"
    echo -e "${RED}⬜ Not Started:${NC}  $NOT_STARTED"
    echo ""
    echo "--------------------------------------"
    
    # Show per-chapter summary
    echo ""
    echo "Per-Chapter Summary:"
    echo ""
    
    for chapter in {1..10}; do
        CH_PREFIX="Chapter $chapter"
        CH_COMPLETED=$(grep -A 20 "$CH_PREFIX" $PROGRESS_FILE | grep -c "✅" || echo "0")
        CH_TOTAL=$(grep -A 20 "$CH_PREFIX" $PROGRESS_FILE | grep -c "⬜\|🟡\|✅" || echo "0")
        
        if [ $CH_TOTAL -gt 0 ]; then
            CH_PERCENT=$((CH_COMPLETED * 100 / CH_TOTAL))
        else
            CH_PERCENT=0
        fi
        
        # Create progress bar
        BAR_FILLED=$((CH_PERCENT / 5))
        BAR_EMPTY=$((20 - BAR_FILLED))
        BAR=$(printf '%*s' "$BAR_FILLED" | tr ' ' '█')
        BAR_EMPTY=$(printf '%*s' "$BAR_EMPTY" | tr ' ' '░')
        
        printf "Chapter %2d: [%s%s] %3d%%\n" $chapter "$BAR" "$BAR_EMPTY" $CH_PERCENT
    done
}

# List incomplete items
list_incomplete() {
    echo "📋 Items to Complete:"
    echo "====================="
    echo ""
    
    grep "⬜" $PROGRESS_FILE | grep -E "Theory|Interview|Lab" | head -20
    
    echo ""
    echo "Next recommended: Start with Chapter 1 Theory"
}

# Mark section as complete
mark_complete() {
    CHAPTER=$1
    SECTION=$2
    
    if [ -z "$CHAPTER" ] || [ -z "$SECTION" ]; then
        echo "Error: Please provide chapter and section"
        echo "Usage: $0 mark [chapter] [section]"
        echo "Example: $0 mark 1 theory"
        return 1
    fi
    
    # Map section names to patterns
    case $SECTION in
        theory)
            PATTERN="Theory (README.md)"
            ;;
        interview)
            PATTERN="Interview Qs"
            ;;
        lab1)
            PATTERN="Lab 1\."
            ;;
        lab2)
            PATTERN="Lab 2\."
            ;;
        lab3)
            PATTERN="Lab 3\."
            ;;
        lab4)
            PATTERN="Lab 4\."
            ;;
        lab5)
            PATTERN="Lab 5\."
            ;;
        all)
            # Mark all in chapter
            sed -i "/Chapter $CHAPTER/,/Chapter $((CHAPTER+1))/s/⬜/✅/g" $PROGRESS_FILE
            echo "✅ Marked all Chapter $CHAPTER sections as complete!"
            return 0
            ;;
        *)
            echo "Unknown section: $SECTION"
            echo "Valid sections: theory, interview, lab1, lab2, lab3, lab4, lab5, all"
            return 1
            ;;
    esac
    
    # Update the specific line
    sed -i "/Chapter $CHAPTER/,/Chapter $((CHAPTER+1))/s/⬜ $PATTERN/✅ $PATTERN/" $PROGRESS_FILE
    
    # Update date
    TODAY=$(date +%Y-%m-%d)
    sed -i "/Chapter $CHAPTER/,/Chapter $((CHAPTER+1))/s/___\/___.*/$TODAY/" $PROGRESS_FILE
    
    echo "✅ Marked Chapter $CHAPTER - $SECTION as complete!"
}

# Show statistics
show_stats() {
    echo "📈 Detailed Statistics"
    echo "====================="
    echo ""
    
    echo "Files in repository:"
    echo "  Markdown files: $(find . -name "*.md" | wc -l)"
    echo "  YAML files: $(find . -name "*.yaml" | wc -l)"
    echo ""
    
    echo "Content breakdown:"
    echo "  Total lines in docs: $(find . -name "*.md" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')"
    echo ""
    
    echo "Completion by type:"
    grep -c "Theory.*✅" $PROGRESS_FILE && echo "  Theory sections: $(grep -c 'Theory.*✅' $PROGRESS_FILE)/10"
    grep -c "Interview.*✅" $PROGRESS_FILE && echo "  Interview sections: $(grep -c 'Interview.*✅' $PROGRESS_FILE)/10"
    grep -c "Lab.*✅" $PROGRESS_FILE && echo "  Labs: $(grep -c 'Lab.*✅' $PROGRESS_FILE)/36"
}

# Main command handler
case "${1:-status}" in
    status)
        show_status
        ;;
    list|todo)
        list_incomplete
        ;;
    mark|complete)
        mark_complete "$2" "$3"
        ;;
    stats|statistics)
        show_stats
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
