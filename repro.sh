trap exit INT TERM EXIT
set -euo pipefail

CONTAINER_NAME=reprocpu_sync

echo "Cleaning and restarting docker sync and files"
docker-sync stop
docker-sync clean
rm -rf *.unison.tmp test.js
docker-sync start
LIMIT=${1:-100000000}
FACTOR=${2:-10}
LINE_COUNT=1000

while [ $(( LINE_COUNT < $LIMIT )) -eq 1 ]; do
    echo "Attempting to repro with line count $LINE_COUNT"
    TEST_COUNT=15
    echo "  Creating and deleting file $TEST_COUNT times with line count $LINE_COUNT and sleep 1 second"

    INDEX=0
    while [ $(( INDEX < TEST_COUNT )) -eq 1 ]; do
        echo "    Create and delete #$(( INDEX + 1 ))"

        yes | head -n "$LINE_COUNT" > test.js || true
        sleep 1
        rm -rf test.js
        sleep 1

        INDEX=$(( INDEX + 1 ))
    done

    INSPECT_COUNT=5
    echo "  Inspecting container stats $INSPECT_COUNT times"
    CPU_SUM=0;
    INDEX=0
    while [ $(( INDEX < INSPECT_COUNT )) -eq 1 ]; do
        echo "    Inspect #$(( INDEX + 1 ))"
        CPU=$(docker stats --no-stream --format "{{.CPUPerc}}" $CONTAINER_NAME | sed 's/%//')
        CPU_SUM=$(echo $CPU_SUM+$CPU | bc )

        INDEX=$(( INDEX + 1 ))
    done
    AVERAGE_CPU=$( echo $CPU_SUM/$INSPECT_COUNT | bc -l )
    echo "    Average CPU $AVERAGE_CPU %"
    CPU_THRESHOLD=70
    if [ $(echo $AVERAGE_CPU'>'$CPU_THRESHOLD | bc -l) -eq 1 ]; then
        echo "REPRO SUCCESS with line count $LINE_COUNT and sleep 1 second"
        echo $LINE_COUNT >> line-repros
        exit
    fi

    echo "  No repro with $LINE_COUNT"

    LINE_COUNT=$(( LINE_COUNT * FACTOR ))
done

echo "REPRO FAILURE"
echo "FAIL" >> line-repros
exit 1
