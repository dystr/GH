using Parameters
using DataFrames
using CSV

mutable struct Node
    cd::Int
    att::Int
end



global abDict = Dict(
                "blaze"=>1,
                "freeze"=>2,
                "blades"=>3,
                "ward"=>4,
                "plane"=>6,
                "gust"=>7,
                "pull"=>8,
                "flow"=>9,
                "channel"=>10,
                "wboon"=>11,
                "bastion"=>12,
                "pboon"=>13,
                "shell"=>14,
                "blaze2"=>15,
                "blaze3"=>16,
                "blaze4"=>17,
                "freeze2"=>18,
                "freeze3"=>19,
                "freeze4"=>20,
                "armoire"=>21)

abilities = CSV.read("Abilities.csv")
abilities.Current = zeros(Int64, length(abDict))

function abInfo()
    abilities[:,[:Name, :Type, :Cooldown, :Cost, :Current, :TLDR]]
end

function output(ability, query)
    label = lowercase(query)
    if label == "description"
        return abilities[:Description][abDict[ability]]
    elseif label == "cd"
        return abilities[:Cooldown][abDict[ability]]
    elseif label == "type"
        return abilities[:Type][abDict[ability]]
    elseif label == "cost"
        return abilities[:Cost][abDict[ability]]
    elseif label == "vectors"
        return abilities[:Vectors][abDict[ability]]
    elseif label == "consumed"
        return abilities[:Consumed][abDict[ability]]
    elseif label == "mechanics"
        return abilities[:Mechanics][abDict[ability]]
    elseif label == "tldr"
        return abilities[:TLDR][abDict[ability]]
    end
end

global adjacents = [(6,2),(1,3),(2,4),(3,5),(4,6),(5,1),(10,8),(7,9),(8,10),(9,7)]


global nodes = Array{Node}
global chargesEO = 0
global recent = 0
global charges = 0
global mode = 0

function setup()
    global nodes = [
                    Node(0,0),
                    Node(0,0),
                    Node(0,0),
                    Node(0,0),
                    Node(0,0),
                    Node(0,0),
                    Node(0,0),
                    Node(0,0),
                    Node(0,0),
                    Node(0,0),
                    ]
    global chargesEO = 2
    global recent = 0
    global cooldowns = fill(0,length(abDict))
    return "You're all set!"
end

function turn()
    global nodes
    global charges
    global cooldowns
    global mode
    global recent = mode
    global mode = 0
    for i in 1:10
        if nodes[i].cd > 0
            nodes[i].cd = nodes[i].cd - 1
        end
    end

    for i in 1:20
        if cooldowns[i] > 0
            cooldowns[i] -=1
        end
    end

    charges = 8
    printNodes()
end



function aoo()
    charges = 4
end

function checkNode(node)
    global nodes
    global chargesEO
    status = false
    while status == false
        if nodes[node].cd != 0
            println("Target node unavailable. Enter a new node to switch, 'x' to abort, or 'e' to override with EO ($chargesEO charges remaining.)")
            n = readline()
            if n == "e"
                nodes[target].cd = 0
                chargesEO -= 1
            elseif n == "x"
                return false
            else
                node = parse(Int, n)
            end
        else
            status = true
        end
    end
    return node
end

function checkFlaw(vectors, recent, ability)
    global nodes
    if recent == output(ability, "type")
        println("This cast will trigger a guts check. Are you sure?")
        if readline() != "y"
            return false
        end
        println("Did the check succeed?")
        if readline() == "y"
            println("Safe.")
        elseif readline() == "n"
            println("Check failed. Disabling a ring at random.")
            if rand((1,2)) == 1
                for i in 1:6
                    nodes[i].cd = 3
                end
            else
                for i in 7:10
                    nodes[i].cd = 3
                end
            end
        end
    end
    for vector in vectors
        if nodes[vector].att == output(ability, "type")
            println("This cast will trigger powerflaw. Are you sure?")
            if readline() != "y"
                return false
            end
            nodes[vector].cd = 4
            if nodes[adjacents[target][1]] == 0 && nodes[adjacents[target][1]] != vector
                nodes[adjacents[target][1]] = 2
            else
                nodes[adjacents[target][1]] += 1
            end
            if nodes[adjacents[target][2]] == 0 && nodes[adjacents[target][2]] != vector
                nodes[adjacents[target][2]] = 2
            else
                nodes[adjacents[target][2]] += 1
            end
            println("Powerflaw triggers: Attacks/DC at -2, nodes disabled.")
        end
    end
end

function updateAttunements!(vectors, type)
    for vector in vectors
        if nodes[vector].att == 0
            nodes[vector].att = type
        elseif nodes[vector].att != type
            nodes[vector].att = 0
        end
    end
end

function printNodes()
    global nodes
    println("Your node states.")
    display(hcat([1;2;3;4;5;6;7;8;9;10],nodes))
end

function updateCooldownsCast!(vectors, consumed, ability)
    global cooldowns
    global nodes
    for vector in vectors
        nodes[vector].cd = 3
    end

    for u in consumed
        nodes[u].cd = 2
    end
    cooldowns[abDict[ability]] = output(ability, "cd")
    println(cooldowns[abDict[ability]])
    println("Nodes and cooldowns have been updated.")
end

function cast(ability)
    global mode
    global cooldowns
    global nodes
    global charges
    global recent
    global chargesEO
    vectors = Array{Int}(undef,output(ability, "vectors"))
    consumed = Array{Int}(undef, output(ability, "consumed"))
    if cooldowns[abDict[ability]] > 0
        return "This ability is on cooldown. Cast aborted."
    end

    if charges < output(ability, "cost")
        return "Not enough charge available. Cast aborted."
    end

    if mode != 0 && mode != output(ability, "type")
        return "Can't cast abilities of different types on the same turn. Cast aborted."
    end

    for i in 1:output(ability, "vectors")
        println("Enter vector $i out of $(output(ability, "vectors")).")
        vector = parse(Int, readline())
        n = checkNode(vector)
        if n != false
            vectors[i] = n
            println("Vector confirmed.")
        else
            return "Cast aborted."
        end
    end

    for c in 1:output(ability, "consumed")
        println("This spell consumes an additional, adjacent, node. Enter one.")
        consumed = parse(Int, readline())
        n = checkNode(consumed)
        if n != false
            consumed[c] = n
        else
            return "Cast aborted."
        end
    end

    if checkFlaw(vectors, recent, ability) == false
        return "Cast aborted."
    end

    updateAttunements!(vectors, output(ability, "type"))
    updateCooldownsCast!(vectors, consumed, ability)
    charges -= output(ability, "cost")
    mode = output(ability, "type")
    println(output(ability, "tldr"))
    return printNodes()
end

function __init__()
    global cooldowns
    session = true
    println("Void powerscript loaded")
    setup()
    turn()
    while session
        println("Enter commands.")
        n = readline()
        if n == "exit"
            session = false
        elseif n == "cast"
            cast(readline())
        elseif n == "end"
            turn()
        elseif n == "aoo"
            aoo()
        elseif n == "nodes"
            printNodes()
        elseif n == "cooldowns"
            display(cooldowns)
        elseif n == "abilities"
            display(abInfo())
        end
    end
end
