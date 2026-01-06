#!/usr/bin/env bash

# ===== CONFIG =====

BOARD_SPACES=8

# Space types: START, PROPERTY, TAX, CHANCE, JAIL
space_name=("Start" "Red Street" "Tax Office" "Blue Avenue" "Chance" "Green Lane" "Jail" "Purple Row")
space_type=("START" "PROPERTY" "TAX" "PROPERTY" "CHANCE" "PROPERTY" "JAIL" "PROPERTY")

# Property costs and rents (same index as board)
space_cost=(0 100 0 120 0 150 0 180)
space_rent=(0 30  0  40  0  50  0  60)

# Owner index: -1 = no owner, 0 = Player 1, 1 = Player 2
space_owner=(-1 -1 -1 -1 -1 -1 -1 -1)

# Player data
player_name=("Player 1" "Player 2")
player_money=(500 500)
player_pos=(0 0)
player_in_jail=(0 0)

NUM_PLAYERS=2
START_MONEY=500
PASS_START_REWARD=100

# ===== FUNCTIONS =====

roll_dice() {
    local d1=$((RANDOM % 6 + 1))
    local d2=$((RANDOM % 6 + 1))
    echo $((d1 + d2))
}

print_board() {
    echo "===== BOARD ====="
    for ((i=0; i<BOARD_SPACES; i++)); do
        local owner="${space_owner[$i]}"
        local owner_symbol=""
        if [[ $owner -ge 0 ]]; then
            owner_symbol="(Owned by ${player_name[$owner]})"
        fi
        echo "[$i] ${space_name[$i]} - ${space_type[$i]} $owner_symbol"
    done
    echo "================="
}

print_status() {
    echo
    echo "===== STATUS ====="
    for ((p=0; p<NUM_PLAYERS; p++)); do
        echo "${player_name[$p]}: £${player_money[$p]}, Position: ${player_pos[$p]}, Jail: ${player_in_jail[$p]}"
    done
    echo "=================="
}

chance_event() {
    local p=$1
    local r=$((RANDOM % 4))

    case $r in
        0)
            echo "Chance: You found money in the street! +£50"
            player_money[$p]=$(( player_money[$p] + 50 ))
            ;;
        1)
            echo "Chance: You paid a fine. -£40"
            player_money[$p]=$(( player_money[$p] - 40 ))
            ;;
        2)
            echo "Chance: Go to Jail!"
            player_pos[$p]=6
            player_in_jail[$p]=1
            ;;
        3)
            echo "Chance: Advance to Start and collect £$PASS_START_REWARD"
            if (( player_pos[$p] != 0 )); then
                player_pos[$p]=0
                player_money[$p]=$(( player_money[$p] + PASS_START_REWARD ))
            fi
            ;;
    esac
}

handle_space() {
    local p=$1
    local pos=${player_pos[$p]}
    local type=${space_type[$pos]}

    echo "You landed on: ${space_name[$pos]} ($type)"

    case $type in
        "START")
            echo "You are just visiting Start."
            ;;
        "PROPERTY")
            local owner=${space_owner[$pos]}
            local cost=${space_cost[$pos]}
            local rent=${space_rent[$pos]}

            if [[ $owner -eq -1 ]]; then
                echo "This property is unowned. Cost: £$cost, Rent: £$rent"
                echo -n "Do you want to buy it? (y/n): "
                read ans
                if [[ $ans == "y" || $ans == "Y" ]]; then
                    if (( player_money[$p] >= cost )); then
                        player_money[$p]=$(( player_money[$p] - cost ))
                        space_owner[$pos]=$p
                        echo "You bought ${space_name[$pos]}!"
                    else
                        echo "You don't have enough money."
                    fi
                else
                    echo "You chose not to buy."
                fi
            else
                if [[ $owner -eq $p ]]; then
                    echo "You own this property."
                else
                    echo "Owned by ${player_name[$owner]}. You must pay rent: £$rent"
                    player_money[$p]=$(( player_money[$p] - rent ))
                    player_money[$owner]=$(( player_money[$owner] + rent ))
                fi
            fi
            ;;
        "TAX")
            local tax=70
            echo "Tax time! You pay £$tax"
            player_money[$p]=$(( player_money[$p] - tax ))
            ;;
        "CHANCE")
            chance_event "$p"
            ;;
        "JAIL")
            echo "You are just visiting Jail (unless sent here by Chance)."
            ;;
    esac
}

check_bankruptcy() {
    for ((p=0; p<NUM_PLAYERS; p++)); do
        if (( player_money[$p] <= 0 )); then
            echo
            echo "💀 ${player_name[$p]} is bankrupt!"
            if (( p == 0 )); then
                echo "🎉 ${player_name[1]} wins!"
            else
                echo "🎉 ${player_name[0]} wins!"
            fi
            exit 0
        fi
    done
}

# ===== MAIN LOOP =====

clear
echo "==== Welcome to Bash‑opoly ===="
print_board

turn=0

while true; do
    print_status

    current_player=$(( turn % NUM_PLAYERS ))
    echo
    echo "---- ${player_name[$current_player]}'s turn ----"

    if (( player_in_jail[$current_player] == 1 )); then
        echo "You are in Jail this turn. You miss your move."
        player_in_jail[$current_player]=0
        ((turn++))
        continue
    fi

    echo -n "Press Enter to roll the dice..."
    read

    roll=$(roll_dice)
    echo "You rolled: $roll"

    old_pos=${player_pos[$current_player]}
    new_pos=$(( old_pos + roll ))

    if (( new_pos >= BOARD_SPACES )); then
        new_pos=$(( new_pos % BOARD_SPACES ))
        echo "You passed Start! Collect £$PASS_START_REWARD"
        player_money[$current_player]=$(( player_money[$current_player] + PASS_START_REWARD ))
    fi

    player_pos[$current_player]=$new_pos
    echo "You move to position $new_pos (${space_name[$new_pos]})"

    handle_space "$current_player"

    check_bankruptcy

    ((turn++))
done
