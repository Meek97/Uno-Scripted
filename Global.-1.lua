--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]
--TableTop Simulator UNO Scripted
--Steam Workshop ID : NA
--Last UpdatedB By: ITzMeek
--Date Last Updated: 5-9-2021
--TTS Version Created On: v13.1.1


local debug_mode = true
--[[ Zone References --]]
local PlayZoneTrigger   --Scripting Zone Object that defines where the play card pile is
local DrawZoneTrigger   --Scripting Zone Object that defines where the draw card pile is

--[[Static Object GUIDs --]]
local PlayZoneMattGUID = 'f82f1f'   --GUID of the 'Play Zone Matt' game object
local DrawZoneMattGUID = '2c2e1c'   --GUID of the 'Draw Zone Matt' game object
local DrawDeckGUID = nil            --GUID of the Draw card deck
local PlayDeckGUID = nil            --GUID of the Play card deck

--[[ Static Objects --]]
local PlayZoneMattObject = nil      --Object reference of the Play Zone Matt game object
local DrawZoneMattObject = nil      --Object reference of the Draw Zone Matt game object
local DrawDeckObject = nil          --Object reference of the Draw Card Deck game object
local PlayDeckGUID = nil            --Object reference of the Play Card Deck game object
local CurrentPlayerToken = nil      --Object reference of the current player token game object

--[[String Variables That Are Used For Different Messages In The UI]]--
Waiting_For_Game_Start_Message="Waiting For The Host (%s) To Start The Game"
Waiting_For_Stacking_Message="Waiting For %s To Stack A Card, Or Draw Cards"
Waiting_For_Wild_Card_Message="Waiting For %s To Pick A Color"
Waiting_For_Trade_Message="Waiting For %s To Trade Their Cards With Another Player"

--Static references of Vector3 Locations to use for the CurrentPlayer token
SEATLOCATIONS = {
    ["GREEN"]  = {  0, 1,  10},
    ["BLUE"]   = { 7, 1,  7},
    ["PURPLE"] = { 10, 1,   0},
    ["PINK"]   = { 7, 1, -7},
    ["WHITE"]  = {  0, 1, -10},
    ["RED"]    = {-7, 1, -7},
    ["ORANGE"] = {-10, 1,   0},
    ["YELLOW"] = {-7, 1,  7}}
--Static reference of Vector3 Locations to use for CPU tokens
CPULOCATIONS = {
    ["GREEN"]  = {  0, 1,  13},
    ["BLUE"]   = { 10, 1,  10},
    ["PURPLE"] = { 13, 1,   0},
    ["PINK"]   = { 10, 1, -10},
    ["WHITE"]  = {  0, 1, -13},
    ["RED"]    = {-10, 1, -10},
    ["ORANGE"] = {-13, 1,   0},
    ["YELLOW"] = {-10, 1,  10}}
--[[Static reference of transform locations for the Current Player label to move aruond the table
SEATLOCATIONS = {
    ["GREEN"]  = {   0,    1.5,    9},
    ["BLUE"]   = { 6.36,   1.5, 6.36},
    ["PURPLE"] = {   9,    1.5,    0},
    ["PINK"]   = { 6.36,   1.5,-6.36},
    ["WHITE"]  = {    0,   1.5,   -9},
    ["RED"]    = {-6.36,   1.5,-6.36},
    ["ORANGE"] = {   -9,   1.5,    0},
    ["YELLOW"] = {-6.36,   1.5, 6.36}}]]
--Static reference of rotations to keep the player label token facing outward for each given color
SEATROTATIONS = {
    ["GREEN"]  = {    0, 360,    0},
    ["BLUE"]   = {    0, 45,    0},
    ["PURPLE"] = {    0, 90,    0},
    ["PINK"]   = {    0, 135,    0},
    ["WHITE"]  = {    0, 180,    0},
    ["RED"]    = {    0,  225,    0},
    ["ORANGE"] = {    0,  270,    0},
    ["YELLOW"] = {    0, 315,    0}}

--Quick reference table for the static Player.<color> objects
PLAYERS_REF = {
    Player.Green,
    Player.Blue,
    Player.Purple,
    Player.Pink,
    Player.White,
    Player.Red,
    Player.Orange,
    Player.Yellow}
--Quick table reference to give a Player object by color name
local COLORTOPLAYER = {
    ["Green"] = Player.Green,
    ["Blue"] = Player.Blue,
    ["Purple"] = Player.Purple,
    ["Pink"] = Player.Pink,
    ["White"] = Player.White,
    ["Red"] = Player.Red,
    ["Orange"] = Player.Orange,
    ["Yellow"] = Player.Yellow}

--List of Computer Controlled Players
local COMPUTERPLAYERS = {}
--Table reference used for CPU picking a wild card color
local WILDCOLORS = {
  "WildButtonRed",
  "WildButtonBlue",
  "WildButtonGreen",
  "WildButtonYellow"}

-- 'ENUM' table for turn states. Used to dictate the game's main state machine loop
local TURN_STATE = {
    ["Play"] = "Play A Card",                   --Default State, the player can play a card as normal
    ["Respond"] = "Resopnd To The Last Card",   --The current player must choose something in response to the last card played
    ["Decide"] = "Make A Decision",             --The current player must choose something in response to a card that they have played
    ["End"] = "End Their Turn"}                 --The current player's turn is over
-- 'ENUM' table for decision states. Used to track certain game states
local DESCISION_STATE ={
    ["Wild"] = "Choose A Color",
    ["SevenZero"] = "Choose Who To Trade With"}


--[[State Machine trackers]]
local PlayerTurnState = nil;    --Tracks the game's current Game State
local DescisionState = nil      --Tracks the game's current Descision State (if there is one)
local clockwise = true          --Determines the direction of turn rotation
local stacking = false          --Tracks if the game state is in Draw Card Stacking
local cardsToDraw  = 0          --Tracks the amount of cards that a player will be dealt at the end of their turn
local cardDrawn = false         --Tracks if a player has draw a card from the Draw Pile this turn

--[[List of players currently setaed (including CPU players)]]
local CurrentPlayerList = {}
local lastCard = {              --Table tracker for details of the last card that was played
    ["GUID"] = nil,
    ["Name"] = nil,
    ["Description"] = nil}
local HouseRules = {            --Table of references to the current set of game rules
    ["Multi_Draw"] = false,
    ["Pass_Turn"] = false,
    ["Stack_Plus4"] = false,
    ["Stack_Plus2"] = false,
    ["Stack_All"] = false,
    ["Call_Uno"] = true,
    ["Seven_Zero"] = false}

local currentPlayer = nil       --Tracks who the current player is
local currentPlayerIndex = nil  --Tracks the index of the current player from 'CurrentPlayerList'
local unoPlayer = nil           --Tracker for any player that has UNO!
local cardPlayed = nil          --Tracks if a card has been played this turn      
local StartingHandAmount = 7    --Amount of cards that players start with at the beginning of the game

--[[===================EVENT RELATED FUNCITONS======================]]
--[[The onLoad event is called after the game save finishes loading.]]
function onLoad()
    InitGame()
end
--[[The onUpdate event is called once per frame.]]
function onUpdate()
end
--[[Called when a player changes color or selects it for the first time. It also returns "Grey" if they disconnect.]]
function onPlayerChangeColor(player_color)
    UpdateCurrentPlayers()
    
    --[[Iterate through all hands at the table to look for cards owned by the same player, and move them to their new color hand]]
    if player_color ~= 'Grey'
    then
        debug('New Player Seated ')
        --Clear out any cards that exist in the new color's hand
        ClearPlayerHand(COLORTOPLAYER[player_color])
        for i=1, #PLAYERS_REF--iterate through all players
        do
            if #PLAYERS_REF[i].getHandObjects() > 0 --if there are object in this player's hand zone
            then
                for j=1,#PLAYERS_REF[i].getHandObjects()--iterate through the objects in this hand zone
                do
                    local temp =  PLAYERS_REF[i].getHandObjects()[j]
                    if temp.getVar('Owner') == Player[player_color].steam_name --if the 'Owner' variable is the same as the player that has changed their color, move the cards to that player
                    then
                        MoveCardToPlayer(temp,Player[player_color])
                    end
                end
            end
        end
    end

end

function onPlayerDisconnect(player_id)
    --collect cards from the disconnected player's hand and return them to the deck
    debug(player_id)
    UpdateCurrentPlayers()
    ClearPlayerHand(player_id)
end

--[[the onObjectEnterScriptingZone event is called when a game object enters a scripting zone]]
function onObjectEnterScriptingZone(zone, enter_object)
    if zone == PlayZoneTrigger
    then
        if enter_object.tag == 'Card'
        then
          if enter_object.held_by_color ~=nil
          then
            if CheckPlayedCard(enter_object)
            then--The card being played is allowed
                PlayCard(enter_object)
            else--The card being played is not allowed
                RejectCard(enter_object,"You Cannot Play A Card")
            end
          end
        end
    end
end
--[[===================END EVENT RELATED FUNCITONS======================]]

--[[===================GAMEPLAY RELATED FUNCITONS======================]]
--[[Function sets all necessary variables to set up the game before starting a round of UNO]]
function InitGame()
    --Hide other UI elements
    UI.setAttribute('PassTurnButton', 'active', 'false')
    UI.setAttribute('UNOButton', 'active', 'false')
    
    --Get reference of the PlayZone and DrawZone matt objects
    PlayZoneMattObject = getObjectFromGUID(PlayZoneMattGUID)
    DrawZoneMattObject = getObjectFromGUID(DrawZoneMattGUID)

    DrawZoneMattObject.UI.hide("DrawButton1")
    DrawZoneMattObject.UI.hide("DrawButton2")
    --Set a few local variables to be used to create our scripting zones
    local TriggerHeight = 20
    local MattPos = PlayZoneMattObject.getPosition()
    local MattScale = PlayZoneMattObject.getBounds().size
    --Spawn a ScriptingZone over the play zone
    PlayZoneTrigger = spawnObject({
        type = 'ScriptingTrigger',
        position = {MattPos.x,TriggerHeight/2,MattPos.z},
        scale = {MattScale.x,TriggerHeight,MattScale.z}
    })
    --Spawn a ScriptingZone over the draw zone
    MattPos = DrawZoneMattObject.getPosition()
    MattScale = DrawZoneMattObject.getBounds().size
    DrawZoneTrigger =  spawnObject({
        type = 'ScriptingTrigger',
        position = {MattPos.x,TriggerHeight/2,MattPos.z},
        scale = {MattScale.x,TriggerHeight,MattScale.z},
        --Create a callback function that will grab a reference to our Draw Card deck object once the scritpting zone has been created
        callback_function = function(obj)
            local DrawZoneObjects = DrawZoneTrigger.getObjects()
            for i=1,#DrawZoneObjects do
                if DrawZoneObjects[i].getGUID() ~= DrawZoneMattGUID
                then
                    DrawDeckObjectGUID = DrawZoneObjects[i].getGUID()
                    DrawDeckObject = getObjectFromGUID(DrawDeckObjectGUID)
                end
            end
        end
    })
    --Update the scripts reference to the currently seated players
    UpdateCurrentPlayers()

    
end
--[[Function is called when the game is ready to start, and handles all of the necessary legwork to start a round of UNO]]
function GameStart()
    --enable the draw draw card buttons
    DrawZoneMattObject.UI.show("DrawButton1")
    DrawZoneMattObject.UI.show("DrawButton2")
    --Hide the main menu
    UI.hide("MainMenuContainer")
    --Mark any computer players that are turned on
    MarkComputerPlayers()
    
    --Give each player their starting hand
    for i=1, #CurrentPlayerList do
        GiveCardsToPlayer(StartingHandAmount, CurrentPlayerList[i])
    end
    --set currentPlayer to first player in Player List
    -- //TODO : Implement ability to determine player 1
    currentPlayerIndex = 1
    currentPlayer = CurrentPlayerList[currentPlayerIndex]
    --Set our PlayerTurnState to 'Play'
    PlayerTurnState = TURN_STATE.Play
    --Shuffle the draw deck pile
    DrawDeckObject.shuffle()
    --Enter the game's state machine loop
    PlayerTurnLoop()

end
--[[Main gameplay loop / state machine. Controls the flow of logic based on conditions of the game]]
function PlayerTurnLoop()
    debug('Enter Turn Loop: '..PlayerTurnState)
    --Turn State Machine
    if PlayerTurnState == TURN_STATE.Respond--For now, the only event that triggers the 'Respond' turn state is a draw card when the Stacking rule is enabled - so we can assume that's the state the game is in at this point
    then
        HideDrawButtons()
        if not isComputerPlayer(currentPlayer)
        then
            --Show the Stacking Card UI Panel to the appropriate player
            UI.setAttribute("StackingCardPanel", "active", "true")
            UI.show("StackingCardPanel")
            UI.setAttribute("StackingCardPanel", "visibility", currentPlayer.color)
            UI.setAttribute("StackingCardPanelText02", "Text", cardsToDraw)
            --Set the Stacking Panel UI Message depending on the type of draw card stacking that is allowed
            local temp = ""
            if HouseRules.Stack_Plus4 == true and HouseRules.Stack_Plus2 == true and HouseRules.Stack_All == false
            then
                if lastCard.Name == "+2"
                then
                    temp = "Stack On Another +2"
                elseif lastCard.Name == "+4"
                then
                    temp = "Stack On Another +4"
                end
            elseif HouseRules.Stack_Plus4 == true and HouseRules.Stack_Plus2 == false and HouseRules.Stack_All == false
            then
                temp = "Stack On Another +4"
            elseif HouseRules.Stack_Plus2 == false and HouseRules.Stack_Plus2 == true and HouseRules.Stack_All == false
            then
                temp = "Stack On Another +2"
            elseif HouseRules.Stack_All == true
            then
                temp = "Stack On +2 or a +4"
            else
                temp = "Stack On Antoher Draw Card"
            end
            UI.setAttribute("StackingCardPanelText01", "Text", temp)
        else
            Wait.time(function()
                DoComputerPlayerTurn(currentPlayer,false)
            end,
            2)
        end

    --=========================================================================================================================
    elseif PlayerTurnState == TURN_STATE.Play
    then
        if lastCard.Description ~= nil --Update the Play Zone matt color tint to match that of the last card played
        then
            PlayZoneMattObject.setColorTint(getColorValueFromCard(lastCard.Description)) 
        end
        ShowDrawButtons()   --Show the 'Draw Card' buttons
        UpdateCurrentPlayerToken()  --Update the Current Player Token
      if isComputerPlayer(currentPlayer)    --If the current player is CPU controlled, do CPU turn
      then
        debug('Current Player is a CPU')
        Wait.time(function()
                        DoComputerPlayerTurn(currentPlayer,false)
                    end,
                    2)
      else
        debug('Current Player is Human')
      end
      --=========================================================================================================================
    elseif PlayerTurnState == TURN_STATE.Decide--For now, the only cards that trigger the 'Decide' turn state is a wild card - so we can assume that's the state the game is in
    then
        HideDrawButtons()   --Hide the draw card buttons

        if DescisionState == DESCISION_STATE.Wild--If the player is deciding what color to make a wild card
        then
          if not isComputerPlayer(currentPlayer)
          then
            --Show the UI panel to pick a wild card color
            UI.setAttribute("WildCardPanel", "active", "true")
            UI.setAttribute("WildCardPanel", "visibility", currentPlayer.color)
          else
            --For now, CPU players will choose a wild card color at random.
            -- //TODO : Allow CPU players to make an informed wild card color decision based on the cards they are holding
            WildPanelButtons(nil,nil,WILDCOLORS[math.random(4)])
          end
        end
    --=========================================================================================================================
    elseif PlayerTurnState == TURN_STATE.End
    then
        HideDrawButtons()   --Hide the draw card buttons
        --Update the play deck's color
        if lastCard.guid ~= nil
        then
            PlayZoneMattObject.setColorTint(getColorValueFromCard(lastCard.Description))
        end

        if not stacking --If the current player is NOT stacking on another draw card / normal flow of play
        then
            --Deal total number of cards to the player
            GiveCardsToPlayer(cardsToDraw,currentPlayer)

            --During normal flow of play, when the stacking rule is not enabled - stacking will always be false, but the amount of cards to draw will be 0 unless from a Draw Card being played
        else
            debug("Stacking Amount:"..cardsToDraw)
        end

        --UNO check for non computer Players
        if not isComputerPlayer(currentPlayer)
        then
            
            if #currentPlayer.getHandObjects() == 1--If the current player only has 1 card left, set the unoPlayer tracker to them
            then
                -- //TODO : Broadcast message that a player has UNO!
                debug(currentPlayer.color .. ' has UNO!')
                unoPlayer = currentPlayer
                ToggleUnoButton(true)
            elseif #currentPlayer.getHandObjects() == 0--If the current player has 0 cards left
            then
                debug('Current Player is out of cards')
                --//TODO : End round of play when player has run out of cards
            else--else if the current player has not reach an UNO or WIN condition, clear the unoPlayer tracker
                unoPlayer = nil
                ToggleUnoButton(false)
            end
        end
        debug('Ending Player\'s Turn')
        EndPlayerTurn()
    end
end
--[[Function called by PlayZoneTrigger: checks if the object entering the zone is a card is a card that is allowed to be played]]
function CheckPlayedCard(card_played)
    if card_played.held_by_color == currentPlayer.color or card_played.getVar("CopmuterPlayerCard") == true --Check that the card being played is held by the current player
    then
        --If the card being played is held by a computer player, we allow it - assuming that the logic controlling computer players is working correctly

        if lastCard.GUID == nil--Assume that this is the first card being played, if lastCard Object is nil
        then
            return true--The card is allowed to be played

        else
            if stacking -- If the game is checking for stacking cards
            then
                if card_played.getName() == "+2" -- check if the card being played is a +2
                then
                    if lastCard.Name == "+2" or HouseRules.Stack_All -- check that the last card played was also a +2, or the ALL stacking rule is enabled
                    then
                        return true -- return true : the card being played is allowed
                    end

                elseif card_played.getName() == "+4" -- check if the card being played is a +4
                then

                    if lastCard.Name == "+4" or HouseRules.Stack_All -- check that the last card played was also a +4, or the ALL stacking rule is enabled
                    then
                        return true -- return true : the card being played is allowed
                    end

                else
                    return false -- return false : the game is waiting for a stacking card, but an eligible card is not being played
                end
            else -- If the game is NOT checking for a stacking card

                if card_played.getDescription() == lastCard.Description --Card being played does matches face / color / wild
                then
                    return true --The card is allowed to be played

                elseif card_played.getName() == lastCard.Name --Card being played does matches face / color / wild
                then
                    return true--The card is allowed to be played

                elseif card_played.getDescription() == 'WILD' --Card being played does matches face / color / wild
                then
                    return true--The card is allowed to be played

                else--Card being played does NOT match face / color / wild
                    return false--The card is NOT allowed to be played
                end
            end

        end
    end
end

--[[Function accepts card from player and adds it to the Draw Deck]]
function PlayCard(card)

    --update cardPlayed tracker
    cardPlayed = true

    --Hide the Turn passing button once a card has been played
    UI.setAttribute('PassTurnButton', 'active', 'false')

    --Update reference to lastCard
    lastCard.GUID = card.getGUID()
    lastCard.Description = card.getDescription()
    lastCard.Name = card.getName()

    --Update individual card variables
    card.setVar('Owner', nil)
    card.setVar('Card_Played', true)

    --Add card to the play deck
    if(card.getVar("CopmuterPlayerCard") == true)
    then
      card.setRotation({0,180,0}, false, true)
      local newPos = PlayZoneTrigger.getPosition()
      card.setPosition({newPos.x,3,newPos.z}, false, true)
    else
      card.setRotationSmooth({0,180,0}, false, true)
      local newPos = PlayZoneTrigger.getPosition()
      card.setPositionSmooth({newPos.x,3,newPos.z}, false, true)
    end

    --//TODO : Update PlayDeckObject reference

    --By default we will set the turn state to 'End'
    PlayerTurnState = TURN_STATE.End
    
    --But there are some exceptions that will change the turn state
    if lastCard.Description == "WILD" -- if the card played is a wild card
    then
        --chand the turn state to decidce : the current player will have to decide what color to call
        PlayerTurnState = TURN_STATE.Decide
        DescisionState = DESCISION_STATE.Wild
    end

    --If the card played was a reverse, change the direction of play
    if lastCard.Name == "reverse"
    then
      clockwise = not clockwise
    end

    --Return to the turn loop
    PlayerTurnLoop()
end

--[[Function rejects card from player and sends it back to their hand]]
function RejectCard(card,message)
    --Grab a function local reference to the player holding the card
    local _player = Player[card.held_by_color]
    --return the card back to the player's hand zone
    card.setPositionSmooth(_player.getHandTransform().position, false, true)
    --send a message to the player that the card cannot be played
    broadcastToColor(message,_player.color,getColorValueFromPlayer(_player.color))
end

--[[Called byu the 'Draw Card' buttons attatched to the drawing deck matt. Deals a card to the player - abiding to related house rules]]
function DrawCardButton(_player)
    
    if _player.color == currentPlayer.color --Check that the player clicking the button is the current player
    then
        if not HouseRules.Multi_Draw and not cardDrawn --If multiple cards are NOT allowed to be drawn per turn, and a card has not yet been drawn this turn
        then
            --set card drawn variable to true
            cardDrawn = true
            --hide the draw card buttons
            HideDrawButtons()
            --give a single card to the player
            GiveCardsToPlayer(1, _player)

            
            Wait.frames(--wait for 5 frames before running this next bit of logic
                function()
                    if not checkForPlayableCard(_player)--If the player does NOT have a card that is able to be played
                    then
                        debug("Player has drawn their card, and has no playable cards")
                        --Set the turn state to end
                        PlayerTurnState = TURN_STATE.End
                        --return to the turn loop
                        PlayerTurnLoop()
                    else--If the player DOES have a card that is able to be played
                        if HouseRules.Pass_Turn and  UI.getAttribute('PassTurnButton', 'active') == 'false' --If the player does have a card that can be played, but the 'Turn Passing' house rule is enabled, show the pass turn button
                        then
                            --active the pass turn button, and set it's visibility to the current player
                            UI.setAttribute('PassTurnButton', 'active', 'true')
                            UI.setAttribute('PassTurnButton', 'visibility', currentPlayer.color)
                        end
                    end 
                end
            , 5)
                
        elseif HouseRules.Multi_Draw -- else, if multiple cards are allowed to be drawn per turn
        then
            -- set card drawn to true
            cardDrawn = true
            -- Give a single card to the player
            GiveCardsToPlayer(1, _player) 

            if HouseRules.Pass_Turn and  UI.getAttribute('PassTurnButton', 'active') == 'false' --If the player does have a card that can be played, but the 'Turn Passing' house rule is enabled, show the pass turn button
            then
                Wait.frames(--wait for 5 frames before running this next bit of logic
                    function()
                        --active the pass turn button, and set it's visibility to the current player
                        UI.setAttribute('PassTurnButton', 'active', 'true')
                        UI.setAttribute('PassTurnButton', 'visibility', currentPlayer.color)
                    end 
                    , 5)
            end
        end
    else
    broadcastToColor("You can only draw cards on your turn", _player.color,getColorValueFromPlayer(_player.color))
  end

end
--[[Our own function to deal cards to a player, so that we can perform any special actions on cards we need to]]
function GiveCardsToPlayer(NumberOfCards,PlayerToDeal)

    debug('Dealing '.. NumberOfCards ..' to '.. PlayerToDeal.color)
    for i=1, NumberOfCards do--loop for the given number of cards to deal

        local cardDealt--create a local object reference of the top card in the draw deck
        cardDealt = DrawDeckObject.takeObject({
          position = PlayerToDeal.getHandTransform().position,
          rotation = {PlayerToDeal.getHandTransform().rotation.x,PlayerToDeal.getHandTransform().rotation.y+180,0},
          index = 1,
          smooth = false})

        cardDealt.setVar('Card_Played', false)--reset 'Card_Played' varianble
        
        if not isComputerPlayer(PlayerToDeal)
        then
            --if the player being dealt to is NOT a CPU - set a 'Owner' variable to the player's steam name
            cardDealt.setVar('Owner', PlayerToDeal.steam_name)
        end

    end
    --reset the number of cards to be drawn
    cardsToDraw = 0
end
--[[Function to move a given card object to a player[object] hand]]
function MoveCardToPlayer(card,receiving_player)
    card.setPosition(receiving_player.getHandTransform().position)
    card.setRotation({receiving_player.getHandTransform().rotation.x,receiving_player.getHandTransform().rotation.y+180,0})
end
--[[Clear hands of cards and return them to the draw deck. Conditional to only clear empty seats]]
function ClearHands(only_empty)
    
    for i=1,#PLAYERS_REF -- loop through all player references
    do
        if PLAYERS_REF[i].seated or isComputerPlayer(PLAYERS_REF[i]) -- if the current player in the loop is a seated player or CPU controlled
        then
            if only_empty == false --check if we are only clearing hand zones that are not being controlled ('only_empty')
            then
                ClearPlayerHand(PLAYERS_REF[i])
            end
        else--else clear the heand zone regaurdless of if it is player/CPU controlled or not
           
            ClearPlayerHand(PLAYERS_REF[i])
        end
    end
end
--[[Clear the hand for a specific player and returning them to the draw deck]]
function ClearPlayerHand(player_to_clear)
    --This color does not have a player or CPU
    if #player_to_clear.getHandObjects() > 0
    then
        --create easy references to the position and rotation of the draw deck pile for use later
        deckPosition = { DrawDeckObject.getPosition()['x'] , DrawDeckObject.getPosition()['y'] + 0.5 , DrawDeckObject.getPosition()['z'] }
        deckRotation = DrawDeckObject.getRotation()

        for i, card in ipairs(player_to_clear.getHandObjects()) --loop through all objects in the hand zone
        do
            --Reset individual card variables
            card.setVar('Owner', nil)
            card.setVar('Card_Played', false)
            
            --move the card back to the draw deck pile
            card.setRotation(deckRotation)
            card.setPosition(deckPosition)
        end
        --shuffle the draw deck afterwards
        DrawDeckObject.shuffle()
    end
end
--[[Handles any game logic that needs to occur at the end of a players turn, and movers the current player to the next player]]
function EndPlayerTurn()
    
    if unoPlayer == nil --If there is not a player with uno, make sure to hide the call UNO buttons
    then
        ToggleUnoButton(false)
    end
    --Determine the next player in turn
    DetermineNextPlayer()

    --reset the state machine to default - 'play'
    PlayerTurnState = TURN_STATE.Play

    if cardPlayed == true
    then--if a card was played this round, check for special cases that would effect the player turn state machine
        if lastCard.Name == "+2"
        then
        if HouseRules.Stack_Plus2 or HouseRules.Stack_ALL
        then--If stacking rules apply, the turn state will be 'Respond'
            PlayerTurnState = TURN_STATE.Respond
            stacking = true
        else -- otherwise, the player's turn will end
            PlayerTurnState = TURN_STATE.End
        end
        --Add 2 to the number of cards to be drawn
        cardsToDraw = cardsToDraw + 2
        elseif lastCard.Name == "+4"
        then
            if HouseRules.Stack_Plus4 or HouseRules.Stack_ALL
            then--If stacking rules apply, the turn state will be 'Respond'
                PlayerTurnState = TURN_STATE.Respond
                stacking = true
            else--otherwise the player's turn will end
                PlayerTurnState = TURN_STATE.End
            end
            --Add 4 to the number of cards to be drawn
            cardsToDraw = cardsToDraw + 4
      elseif lastCard.Name == "skip"
          then--check if the last card played was a skip card
            debug('Last Card skip. Ending next players turn')
            PlayerTurnState = TURN_STATE.End
      end
    end

    cardPlayed = false --reset the cardPlayed variable
    cardDrawn = false   --reset the cardDrawn variable

    debug('\n')
    --Return to the game state loop
    PlayerTurnLoop()
end
--[[Updates the currentPlayer & currentPlayerIndex variables to the next player in the turn order]]
function DetermineNextPlayer()
    --Change currentPlayerIndex to the next player, based on the rotation of play
    if clockwise == true
    then
        --If statements for index wrap-around conditions
        if currentPlayerIndex + 1 > #CurrentPlayerList
        then
            currentPlayerIndex = 1
        else
            currentPlayerIndex = currentPlayerIndex + 1
        end
    else
        --If statements for index wrap-around conditions
        if currentPlayerIndex - 1 < 1
        then
        currentPlayerIndex = #CurrentPlayerList
        else
        currentPlayerIndex = currentPlayerIndex - 1
        end
    end

    
    --set the currentPlayer to the new currentPlayerIndex
    currentPlayer = CurrentPlayerList[currentPlayerIndex]
    debug('Current Player is now ' .. currentPlayer.color)
end
--[[Grab players that are currently seated and populate 'CurrentPlayerList']]
function UpdateCurrentPlayers()

    local counter = 1

    --Empty our reference tables
    CurrentPlayerList = {}

    for i = 1, #PLAYERS_REF
    do--Go through our static PLAYERS_REF table
        local _player = PLAYERS_REF[i]
        if _player.admin
        then--Check if the player is the host or a promoted player

        end

        if _player.seated
        then
            CurrentPlayerList[counter] = _player--If a given player is seated add that player to our reference table
            counter = counter + 1
        else
            if isComputerPlayer(_player)--if the given player is CPU controlled, we also add it to our reference table
            then
                debug(_player.color .. ' is a CPU')
                CurrentPlayerList[counter] = _player
                counter = counter + 1
            end
        end
    end
    --//Investigate : is this section of code still being used?
    if currentPlayer ~= nil
    then
        if #CurrentPlayerList > 0
        then
            if currentPlayer.seated == false and not isComputerPlayer(currentPlayer)
            then
                debug('Current Player is not seated!')
                EndPlayerTurn()
            end
        end
    end
    --Update menu buttons for CPU controlled buttons
    UpdateMenuLabels()

end
--[[Moves the token that denotes who the current player is]]
function UpdateCurrentPlayerToken()
    debug('Updating Current Player Token For ' .. currentPlayer.color)
    if CurrentPlayerToken == nil -- if the CurrentPlayerToken game object currently doesn't exist - spawn one
    then
        CurrentPlayerToken = spawnObject({
            type = "PiecePack_Suns",
            position = SEATLOCATIONS[currentPlayer.color:upper()],
            rotation = SEATROTATIONS[currentPlayer.color:upper()],
            scale = {0.8,0.5,0.8},
            sound = false})
            CurrentPlayerToken.setColorTint(getColorValueFromPlayer(currentPlayer.color))
            CurrentPlayerToken.use_gravity = false
            CurrentPlayerToken.UI.setXmlTable( -- Apply XML UI to it that shows the current player text
                {
                    {
                        tag="HorizontalLayout",
                        attributes=
                        {
                            height=600,
                            width=1000,
                            position="0 0 -10",
                        },
                        children=
                        {
                            {
                                tag="Text",
                                attributes=
                                {
                                    text= "Current Player",
                                    fontSize="130",
                                    color= "white",
                                    outline="black",
                                    outlineSize="4 4"
                                },
                            },
                        }
                    }
                })
    else--If the token game object already exists, update the existing values
        CurrentPlayerToken.setColorTint(getColorValueFromPlayer(currentPlayer.color))
        CurrentPlayerToken.setRotation(SEATROTATIONS[currentPlayer.color:upper()])
        CurrentPlayerToken.setPosition(SEATLOCATIONS[currentPlayer.color:upper()])
    end
end
--[[===================END GAMEPLAY RELATED FUNCITONS======================]]
--[[===================UI RELATED FUNCITONS======================]]
--[[Updates the 'Draw Card' buttons to be visible for the current player]]
function ShowDrawButtons()
    --Show the draw card buttons
    DrawZoneMattObject.UI.Show("DrawButton1")
    DrawZoneMattObject.UI.show("DrawButton2")
    --set te visibility to the current player
    DrawZoneMattObject.UI.setAttribute("DrawButton1", "visibility", currentPlayer.color)
    DrawZoneMattObject.UI.setAttribute("DrawButton2", "visibility", currentPlayer.color)
    
    if HouseRules.Call_Uno == false--If scripted uno is disabled, allow the draw cards to be shown to any player that has UNO for when they need to draw 2 cards on their own
    then
        DrawZoneMattObject.UI.setAttribute("DrawButton1", "visibility", unoPlayer.color)
        DrawZoneMattObject.UI.setAttribute("DrawButton2", "visibility", unoPlayer.color)
    end
end
--[[Completely hides the 'Draw Card' buttons]]
function HideDrawButtons()
    DrawZoneMattObject.UI.Hide("DrawButton1")
    DrawZoneMattObject.UI.Hide("DrawButton2")
end
--[[Called by the wild card "pick a color" panel]]
function WildPanelButtons(a,b, ID)
    
    --modify the lastCard description depending on what color the player chooses
    if ID == "WildButtonRed"
    then
        lastCard.Description = "RED"
    elseif ID == "WildButtonBlue"
    then
        lastCard.Description = "BLUE"
    elseif ID == "WildButtonYellow"
    then
        lastCard.Description = "YELLOW"
    elseif ID == "WildButtonGreen"
    then
        lastCard.Description = "GREEN"
    end

    --Hide the wild card panel, now that we are done with it
    UI.hide("WildCardPanel")
    debug('Wild Card Descion: '..lastCard.Description)
    --Exit out of the 'decision' state and run the turn loop again
    PlayerTurnState = TURN_STATE.End
    PlayerTurnLoop()
end
--[[Called by the 'Stacking Card Panel' UI when someone has clicked the 'Don't Stack' button]]
function StackingPanelButtons(a,b,ID)
    --set the stacking tracker to false
    stacking = false
    --Update the state machine to the end of the player's turn
    PlayerTurnState = TURN_STATE.End
    --Hide the UI panel
    UI.Hide("StackingCardPanel");
    --return to state machine loop
    PlayerTurnLoop()
end
--[[Called by Main Menu dropdown to change Card Drawing rules]]
function UpdateDrawingRules(a,opt)
    --Update HouseRules variable for Drawing cards based on the menu item
    if opt == "Only draw one card per turn"
    then
        HouseRules.Multi_Draw = false
        --If the rule is set to 'Only Draw One Card..' disable the menu option for turn passing
        UI.setAttribute("TurnPassingRow", "active", "false")
    elseif opt == "Draw many cards per turn"
    then
        HouseRules.Multi_Draw = true
        UI.setAttribute("TurnPassingRow", "active", "true")
    end
    debug("Draw Multiple Cards: " .. tostring(HouseRules.Multi_Draw) .. "\n")
end
--[[Called by the Main Menu dropdown to change Card Stacking rules]]
function UpdateStackingRules(a,opt)
    --Update the House Rules for stacking draw cards based on the menu options
    if opt == "Don't Allow Card Stacking"
    then
        HouseRules.Stack_All = false
        HouseRules.Stack_Plus2 = false
        HouseRules.Stack_Plus4 = false
    elseif opt == "Only Allow Stacking +2 Cards"
    then
        HouseRules.Stack_All = false
        HouseRules.Stack_Plus2 = true
        HouseRules.Stack_Plus4 = false
    elseif opt == "Only Allow Stacking +4 Cards"
    then
        HouseRules.Stack_All = false
        HouseRules.Stack_Plus2 = false
        HouseRules.Stack_Plus4 = true
    elseif opt == "Allow Both Stacking Options"
    then
        HouseRules.Stack_All = false
        HouseRules.Stack_Plus2 = true
        HouseRules.Stack_Plus4 = true
    elseif opt == "Allow ALL Stacking"
    then
        HouseRules.Stack_All = true
        HouseRules.Stack_Plus2 = true
        HouseRules.Stack_Plus4 = true
    end

    debug("+2 Card Stacking: ".. tostring(HouseRules.Stack_Plus2))
    debug("+4 Card Stacking: ".. tostring(HouseRules.Stack_Plus4))
    debug("All Card Stacking: ".. tostring(HouseRules.Stack_All) .. "\n")
end
--[[Called by the Main Menu Toggle to change turn passing rules]]
function UpdateTurnpassingRules(a,opt)
    --Update the House Rules variable for turn passing, based on the menu option
    if opt == "True"
    then
        HouseRules.Pass_Turn = true

    elseif opt == "False"
    then
        HouseRules.Pass_Turn = false
    end
    debug("Turn Passing: ".. tostring(HouseRules.Pass_Turn) .. "\n")
end
--[[Called by the Main Menu toggle to change scripted uno calling rules]]
function UpdateScriptedUnoRules(a,opt)
    --Update the house rules variable for scripted uno calling based on the menu option
    if opt == "True"
    then
        HouseRules.Call_Uno = true
    elseif opt == "False"
    then
        HouseRules.Call_Uno = false
    end
    debug("Scipted Uno: ".. tostring(HouseRules.Call_Uno) .. "\n")
end
--[[Called by the Main Menu toggle to change 7-0 rules]]
function UpdateSevenZeroRules(a,opt)
    --//TODO: 7-0 menu option is currently disabled because it has not been implemented into this version of the script
    --Update the house rule variable for 7-0 rules based on the menu option
    if opt == "True"
    then
        HouseRules.Seven_Zero = true
    elseif opt == "False"
    then
        HouseRules.Seven_Zero = false
    end
    debug("7-0 Rules: ".. tostring(HouseRules.Seven_Zero) .. "\n")
end
--[[Called by the "Hide/Show Main Menu" button]]
function ToggleMenu(a,b, ID)
    --Hides the Main Menu UI and all associated UI elements
    if UI.getAttribute("MainMenuPanel", "active") == 'true'
    then
        UI.setAttribute("FakePlayerPanel", "active", "false")
        UI.setAttribute("MainMenuPanel", "active", "false")
        UI.setAttribute("MainMenuContainer", "height", "5%")
        UI.setAttribute("HideMenuButton", "height", "100%")
        UI.setAttribute("HideMenuButton", "text", "Show Main Menu")
    else
        UI.setAttribute("FakePlayerPanel", "active", "true")
        UI.setAttribute("MainMenuPanel", "active", "true")
        UI.setAttribute("MainMenuContainer", "height", "75%")
        UI.setAttribute("HideMenuButton", "height", "5%")
        UI.setAttribute("HideMenuButton", "text", "Hide Main Menu")
    end
end
--[[Called by the 'Pass Turn' UI Button]]
function PassTurnButton()
    --Disables the UI button after being clicked
    UI.setAttribute('PassTurnButton', 'active', 'false')
    --set's the player's turn sate to end
    PlayerTurnState = TURN_STATE.End
    --returns to the state machine loop to end their turn
    PlayerTurnLoop()
end
--[[Show or hide the uno button]]
function ToggleUnoButton(Toggle)
    --Toggles the call UNO button on or off
    if Toggle
    then
        math.randomseed(os.time())
        UI.setAttribute('UNOButton', 'active', 'true')
        --Slightly randomize the position of the call UNO button every time it is shown
        UI.setAttribute('UNOButton', 'offsetXY', ''..math.random(-500,500)..' 250')
        --Modify the color to match the player that has UNO
        UI.setAttribute('UNOButton', 'color', unoPlayer.color)

    else
        UI.setAttribute('UNOButton', 'active', 'false')
    end
end
--[[Called by the 'Call UNO' button]]
function CallUnoButton(a,b,ID)
    --Hide the call uno button once it has been clicked
    ToggleUnoButton(false)

    if unoPlayer ~= nil -- check that there is still a player with UNO
    then
        tempPlayer = unoPlayer --create a temporary reference to the player that has UNO for use later
        unoPlayer = nil -- first, clear the UNO tracker to avoid multiple calls further

        if not a.color == unoPlayer.color-- if the person who clicked the uno button is NOT the same person that has UNO
        then
            --deal 2 cards to the player with UNO (using the temp player reference that we made earlier, since we already cleared the UNO tracker)
            GiveCardsToPlayer(2,tempPlayer)
        end
    end
end
--[[Update player labels for CPU menu toggles, and Player One selector]]
function UpdateMenuLabels()
    --Update each of the CPU control buttons to indicate if a player is seated at that color, if the seat is empty, or if the seat is marked for CPU control
    if Player.white.seated
    then
        UI.setAttribute("CPUButtonWhite", "text", Player.white.steam_name)
        UI.setAttribute("CPUButtonWhite", "interactable", 'false')
    else
        UI.setAttribute("CPUButtonWhite", "interactable", 'true')
        if isComputerPlayer(Player.white)
        then
            UI.setAttribute("CPUButtonWhite", "text", "CPU")
        else
            UI.setAttribute("CPUButtonWhite", "text", "Empty")
        end
    end

    if Player.red.seated
    then
        UI.setAttribute("CPUButtonRed", "text", Player.red.steam_name)
        UI.setAttribute("CPUButtonRed", "interactable", 'false')
    else
        UI.setAttribute("CPUButtonRed", "interactable", 'true')
        if isComputerPlayer(Player.red)
        then
            UI.setAttribute("CPUButtonRed", "text", "CPU")
        else
            UI.setAttribute("CPUButtonRed", "text", "Empty")
        end
    end

    if Player.orange.seated
    then
        UI.setAttribute("CPUButtonOrange", "text", Player.orange.steam_name)
        UI.setAttribute("CPUButtonOrange", "interactable", 'false')
    else
        UI.setAttribute("CPUButtonOrange", "interactable", 'true')
        if isComputerPlayer(Player.orange)
        then
            UI.setAttribute("CPUButtonOrange", "text", "CPU")
        else
            UI.setAttribute("CPUButtonOrange", "text", "Empty")
        end
    end

    if Player.yellow.seated
    then
        UI.setAttribute("CPUButtonYellow", "text", Player.yellow.steam_name)
        UI.setAttribute("CPUButtonYellow", "interactable", 'false') 
    else
        UI.setAttribute("CPUButtonYellow", "interactable", 'true')
        if isComputerPlayer(Player.yellow)
        then
            UI.setAttribute("CPUButtonYellow", "text", "CPU")
        else
            UI.setAttribute("CPUButtonYellow", "text", "Empty")
        end
    end

    if Player.green.seated
    then
        UI.setAttribute("CPUButtonGreen", "text", Player.green.steam_name)
        UI.setAttribute("CPUButtonGreen", "interactable", 'false')
    else
        UI.setAttribute("CPUButtonGreen", "interactable", 'true')
        if isComputerPlayer(Player.green)
        then
            UI.setAttribute("CPUButtonGreen", "text", "CPU")
        else
            UI.setAttribute("CPUButtonGreen", "text", "Empty")
        end
    end

    if Player.blue.seated
    then
        UI.setAttribute("CPUButtonBlue", "text", Player.Blue.steam_name)
        UI.setAttribute("CPUButtonBlue", "interactable", 'false')
    else
        UI.setAttribute("CPUButtonBlue", "interactable", 'true')
        if isComputerPlayer(Player.blue)
        then
            UI.setAttribute("CPUButtonBlue", "text", "CPU")
        else
            UI.setAttribute("CPUButtonBlue", "text", "Empty")
        end
    end

    if Player.Purple.seated
    then
        UI.setAttribute("CPUButtonPurple", "text", Player.purple.steam_name) 
        UI.setAttribute("CPUButtonPurple", "interactable", 'false')
    else
        UI.setAttribute("CPUButtonPurple", "interactable", 'true')
        if isComputerPlayer(Player.purple)
        then
            UI.setAttribute("CPUButtonPurple", "text", "CPU")
        else
            UI.setAttribute("CPUButtonPurple", "text", "Empty")
        end
    end

    if Player.pink.seated
    then
        UI.setAttribute("CPUButtonPink", "text", Player.pink.steam_name)
        UI.setAttribute("CPUButtonPink", "interactable", 'false')
    else
        UI.setAttribute("CPUButtonPink", "interactable", 'true')
        if isComputerPlayer(Player.pink)
        then
            UI.setAttribute("CPUButtonPink", "text", "CPU")
        else
            UI.setAttribute("CPUButtonPink", "text", "Empty")
        end
    end
end
--[[Called by the CPU Player Buttons]]
function CPUPlayerButton(a,b,ID)
    --When a CPU control button is clicked, enable or disable the CPU control for that color
    if ID == 'CPUButtonWhite'
    then
        if isComputerPlayer(Player.white)
        then
            ToggleComputerPlayer(Player.white,false)
        else
            ToggleComputerPlayer(Player.white,true)
        end
    end

    if ID == 'CPUButtonRed'
    then
        if isComputerPlayer(Player.red)
        then
            ToggleComputerPlayer(Player.red,false)
        else
            ToggleComputerPlayer(Player.red,true)
        end
    end

    if ID == 'CPUButtonOrange'
    then
        if isComputerPlayer(Player.orange)
        then
            ToggleComputerPlayer(Player.orange,false)
        else
            ToggleComputerPlayer(Player.orange,true)
        end
    end

    if ID == 'CPUButtonYellow'
    then
        if isComputerPlayer(Player.yellow)
        then
            ToggleComputerPlayer(Player.yellow,false)
        else
            ToggleComputerPlayer(Player.yellow,true)
        end
    end

    if ID == 'CPUButtonGreen'
    then
        if isComputerPlayer(Player.green)
        then
            ToggleComputerPlayer(Player.green,false)
        else
            ToggleComputerPlayer(Player.green,true)
        end
    end

    if ID == 'CPUButtonBlue'
    then
        if isComputerPlayer(Player.blue)
        then
            ToggleComputerPlayer(Player.blue,false)
        else
            ToggleComputerPlayer(Player.blue,true)
        end
    end

    if ID == 'CPUButtonPurple'
    then
        if isComputerPlayer(Player.purple)
        then
            ToggleComputerPlayer(Player.purple,false)
        else
            ToggleComputerPlayer(Player.purple,true)
        end
    end

    if ID == 'CPUButtonPink'
    then
        if isComputerPlayer(Player.pink)
        then
            ToggleComputerPlayer(Player.pink,false)
        else
            ToggleComputerPlayer(Player.pink,true)
        end
    end

    UpdateCurrentPlayers()
end
--[[===================END UI RELATED FUNCITONS======================]]
--[[===================CPU PALYER RELATED FUNCITONS======================]]
--[[Returns true or false if the given player is a CPU controlled player]]
function isComputerPlayer(PlayertoCheck)
    
    for i=1, #COMPUTERPLAYERS do--loop through all computer players

        if COMPUTERPLAYERS[i] == PlayertoCheck --if the player to check is in the list
        then
            return true --return true and exit the function
        end
    end
    --if we make to this point in the function the player to check did not match any CPU players in the list
    return false
end
--[[Adds or Removes a color from the CPU control list, given 'Toggle']]
function ToggleComputerPlayer(PlayerToToggle,Toggle)
    if Toggle
    then--if toggle is true, we are adding a computer player
        table.insert(COMPUTERPLAYERS,PlayerToToggle)
    else--if toggle is false, we are removing a computer player
        for i=1, #COMPUTERPLAYERS do

            if COMPUTERPLAYERS[i] == PlayerToToggle
            then
                --remove the given player from our COMPUTERPLAYERS list
                table.remove(COMPUTERPLAYERS, i)
            end
        end
    end
end
--[[Places a 'CPU' token in front of the seats of CPU controlled colors]]
function MarkComputerPlayers()
    for i=1, #COMPUTERPLAYERS do --loop through all CPU controlled players
        
        tempObject = spawnObject({  --Spawn a token piece
            type = "PiecePack_Suns",
            position = CPULOCATIONS[COMPUTERPLAYERS[i].color:upper()],
            rotation = SEATROTATIONS[COMPUTERPLAYERS[i].color:upper()],
            scale = {0.8,0.5,0.8},
            sound = false})
            tempObject.setColorTint(getColorValueFromPlayer(COMPUTERPLAYERS[i].color))
            tempObject.use_gravity = false
            tempObject.UI.setXmlTable(  --Add some UI elements to it that say this is a CPU controlled player
                {
                    {
                        tag="HorizontalLayout",
                        attributes=
                        {
                            height=600,
                            width=1000,
                            position="0 0 -10",
                        },
                        children=
                        {
                            {
                                tag="Text",
                                attributes=
                                {
                                    text= "CPU",
                                    fontSize="130",
                                    color= "white",
                                    outline="black",
                                    outlineSize="4 4"
                                },
                            },
                        }
                    }
                })
    end
end
--[[All the logic required for CPU controlled turns]]
function DoComputerPlayerTurn(_player,cardDrawn)
    debug('Doing CPU turn for '.. _player.color)
    local cardPlayed = false    --local variable for if a card has been played during this turn
    local handTotal = #_player.getHandObjects() --create a quick refence to the number of cards in the CPU's hand right now
    debug('CPU Player has ' .. handTotal .. ' cards')
    
    for i=1,handTotal -- loop through all of the cards in their hand
    do
        local tempCard = _player.getHandObjects()[i]    --grab a quick reference to the current card in the loop being checked
        tempCard.setVar("CopmuterPlayerCard", true) --take this time to set a individual card variable noting that it is being held by a CPU
        if CheckPlayedCard(tempCard)--Check if the current card could be played right now
        then
            --Play the card if it can be
            PlayCard(tempCard)
            cardPlayed = true

            if handTotal == 2
            then
                --if the CPU had 2 cards, and was able to play 1 - they now have UNO
                unoPlayer = _player
                ToggleUnoButton(true)
            else
                --else - the CPU has played a card so we can reset the UNO trackers
                unoPlayer = nil
                ToggleUnoButton(false)
            end
            --Now that we have played a card we can break out of the loop
            break
        end
    end
    if cardPlayed == false--Check if we've reached this point in the function withuot playing a card
    then
        debug('No card can be played')
        if stacking == true--Check if the CPU was trying to stack a draw card but was unable to
        then
            --reset stacking tracker and end the CPU's turn
            stacking = false
            PlayerTurnState = TURN_STATE.End
            PlayerTurnLoop()
        else--else the CPU was NOT trying to stack a draw card
            
            if cardDrawn == false --check if the CPU has drawn a card from the Draw deck yet
            then
                --if not - draw a card and run through this function again
                GiveCardsToPlayer(1,_player)
                Wait.time(function()
                    --but this time, calling the function with the 'cardDrawn' parameter to true
                    DoComputerPlayerTurn(currentPlayer,true)
                end,
                1)

            --//TODO : I think I need to add additional conditions to the CPU turn machine for the different card drawing rules
            else--If we've reached this point in the function, the CPU does NOT have a card that can be played, and the CPU can NOT draw a card from the draw pile
                --So we will end the CPU's turn
                unoPlayer = nil
                ToggleUnoButton(false)
                PlayerTurnState = TURN_STATE.End
                PlayerTurnLoop()
            end
        end
    end
end
--[[Checks the hand of the given player for playable cards]]
function checkForPlayableCard(_player)
    for i=1,#_player.getHandObjects()--loop through all objects in the given player's hand
    do
        local tempCard = _player.getHandObjects()[i]--Grab a temporary refence to the current card in the loop
        if CheckCard(tempCard)--check if this card is allowed to be played at this time
        then
            return true
        end
    end
    return false
end
--[[Checks if the given card is playable or not]]
function CheckCard(_card)
    if _card.getDescription() == lastCard.Description
    then--Card being played does matches face / color / wild
        return true--The card is allowed to be played
    elseif _card.getName() == lastCard.Name
    then
        return true--The card is allowed to be played
    elseif _card.getDescription() == 'WILD'
    then
        return true--The card is allowed to be played
    elseif lastCard.Description == nil
    then
        return true
    else--Card being played does not match face / color / wild
        return false--The card is not allowed to be played
    end
end
--[[===================END CPU PLAYER RELATED FUNCITONS======================]
--[[===================HELPER FUNCITONS======================]]
--Return a color code give a PLAYERS_REF color string
function getColorValueFromPlayer (player_color)
    if player_color == "Green"
    then
        return {0.129,0.701,0.168}

    elseif player_color == "Blue"
    then
        return {0.118, 0.53, 1}

    elseif player_color == "Purple"
    then
        return {0.627, 0.125, 0.941}

    elseif player_color == "Pink"
    then
        return {0.96, 0.439, 0.807}

    elseif player_color == "White"
    then
        return {1, 1, 1}

    elseif player_color == "Red"
    then
        return {0.856, 0.1, 0.094}

    elseif player_color == "Orange"
    then
        return {0.956, 0.392, 0.113}

    elseif player_color == "Yellow"
    then
        return {0.905, 0.898, 0.172}

    elseif player_color == "Grey"
    then
        return {0.5, 0.5, 0.5}

    elseif player_color == "Black"
    then
        return {0.25, 0.25, 0.25}
    end
end
--[[Helper Function to return a color code given a card color string]]
function getColorValueFromCard (card_color)

    if card_color == "GREEN"
    then
        return {0.129,0.701,0.168}
    end

    if card_color == "BLUE"
    then
        return {0.118, 0.53, 1}
    end

    if card_color == "RED"
    then
        return {0.856, 0.1, 0.094}
    end

    if card_color == "YELLOW"
    then
        return {0.905, 0.898, 0.172}
    end

end
--[[Helper function to print a message to the console with some consistent formatting, and controlled by a global 'debug' variable]]
function debug(string)
  if debug_mode == true
  then
    log('[DEBUG]  '.. tostring(string))
  end
end
--[[===================END HELPER FUNCITONS======================]]