--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]
--TableTop Simulator UNO Scripted
--Steam Workshop ID : NA
--Last UpdatedB By: ITzMeek
--Date Last Updated: 12-16-2020
--TTS Version Created On: v12.4.4


local debug_mode = true
--[[ Zone References --]]
local PlayZoneTrigger
local DrawZoneTrigger

--[[Static Object GUIDs --]]
local PlayZoneMattGUID = 'f82f1f'
local DrawZoneMattGUID = '2c2e1c'
local DrawDeckGUID = nil
local PlayDeckGUID = nil

--[[ Static Objects --]]
local PlayZoneMattObject = nil
local DrawZoneMattObject = nil
local DrawDeckObject = nil
local PlayDeckGUID = nil


--Static reference of transform locations for 'CPU' labels. These locations are closer to the edge of the table than the 'SEATLOCATIONS' table
LABELLOCATIONS = {
    ["GREEN"]  = {  0, 1,  13},
    ["BLUE"]   = { 10, 1,  10},
    ["PURPLE"] = { 13, 1,   0},
    ["PINK"]   = { 10, 1, -10},
    ["WHITE"]  = {  0, 1, -13},
    ["RED"]    = {-10, 1, -10},
    ["ORANGE"] = {-13, 1,   0},
    ["YELLOW"] = {-10, 1,  10}}
--Static reference of transform locations for the Current Player label to move aruond the table
SEATLOCATIONS = {
    ["GREEN"]  = {   0,    1.5,    9},
    ["BLUE"]   = { 6.36,   1.5, 6.36},
    ["PURPLE"] = {   9,    1.5,    0},
    ["PINK"]   = { 6.36,   1.5,-6.36},
    ["WHITE"]  = {    0,   1.5,   -9},
    ["RED"]    = {-6.36,   1.5,-6.36},
    ["ORANGE"] = {   -9,   1.5,    0},
    ["YELLOW"] = {-6.36,   1.5, 6.36}}
--Static reference of rotations to keep the player label token facing outward for each given color
SEATROTATIONS = {
    ["GREEN"]  = {    0, 180,    0},
    ["BLUE"]   = {    0, 225,    0},
    ["PURPLE"] = {    0, 270,    0},
    ["PINK"]   = {    0, 315,    0},
    ["WHITE"]  = {    0, 360,    0},
    ["RED"]    = {    0,  45,    0},
    ["ORANGE"] = {    0,  90,    0},
    ["YELLOW"] = {    0, 135,    0}}

--Reference table of colors present at this table
PLAYERS_REF = {
    Player.Green,
    Player.Blue,
    Player.Purple,
    Player.Pink,
    Player.White,
    Player.Red,
    Player.Orange,
    Player.Yellow}
--Return a player object by using a color
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
local COMPUTERPLAYERS = {
  Player.Orange,
  Player.Yellow,
  Player.Green,
  Player.Blue,
  Player.Purple,
  Player.Pink,
  Player.Red}
local WILDCOLORS = {
  "WildButtonRed",
  "WildButtonBlue",
  "WildButtonGreen",
  "WildButtonYellow"
}

local TURN_STATE = {
    ["Respond"] = "Resopnd To The Last Card",
    ["Play"] = "Play A Card",
    ["Decide"] = "Make A Decision",
    ["End"] = "End Their Turn"}
local DESCISION_STATE ={
    ["Wild"] = "Choose A Color",
    ["SevenZero"] = "Choose Who To Trade With"}
--[[State Machine trackers]]
local PlayerTurnState = nil;
local DescisionState = nil
local clockwise = true

local CurrentPlayerList = {}

local currentPlayer = nil     --track of who is the current player
local currentPlayerIndex = nil
local cardPlayerd = nil       --track if a card has been played yet for the current turn
local lastCard = {
    ["GUID"] = nil,
    ["Name"] = nil,
    ["Description"] = nil}
local HouseRules = {
    ["Multi_Draw"] = false,
    ["Pass_Turn"] = false,
    ["Stack_Plus4"] = false,
    ["Stack_Plus2"] = false,
    ["Stack_All"] = false,
    ["Call_Uno"] = true,
    ["Seven_Zero"] = false}



--The onLoad event is called after the game save finishes loading.
function onLoad()

    --Get reference of the PlayZone and DrawZone matt objects
    PlayZoneMattObject = getObjectFromGUID(PlayZoneMattGUID)
    DrawZoneMattObject = getObjectFromGUID(DrawZoneMattGUID)
    MenuTokenObject = getObjectFromGUID(MenuTokenGUID)

    DrawZoneMattObject.UI.hide("DrawButton1")
    DrawZoneMattObject.UI.hide("DrawButton2")
    --Height of the scripting zones
    local TriggerHeight = 20

    --grab some local variable information
    local MattPos = PlayZoneMattObject.getPosition()
    local MattScale = PlayZoneMattObject.getBounds().size


    --Spawn a ScriptingZone over the play zone
    PlayZoneTrigger = spawnObject({
        type = 'ScriptingTrigger',
        position = {MattPos.x,TriggerHeight/2,MattPos.z},
        scale = {MattScale.x,TriggerHeight,MattScale.z}
    })

    MattPos = DrawZoneMattObject.getPosition()
    MattScale = DrawZoneMattObject.getBounds().size

    --Spawn a ScriptingZone over the draw zone
    DrawZoneTrigger =  spawnObject({
        type = 'ScriptingTrigger',
        position = {MattPos.x,TriggerHeight/2,MattPos.z},
        scale = {MattScale.x,TriggerHeight,MattScale.z},
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

    UpdateCurrentPlayers()

end

--he onUpdate event is called once per frame.
function onUpdate()
    --[[ print('onUpdate loop!') --]]
end

--the onObjectEnterScriptingZone event is called when a game object enters a scripting zone
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

--Function is called when the game is ready to start, and handles all of the necessary legwork to start a round of UNO
function GameStart()
  DrawZoneMattObject.UI.show("DrawButton1")
  DrawZoneMattObject.UI.show("DrawButton2")
  UI.hide("MainMenuContainer")
  MarkComputerPlayers()
  for i=1, #CurrentPlayerList do
    GiveCardsToPlayer(7, CurrentPlayerList[i])
  end
    --set currentPlayer to first player in Player List
    currentPlayerIndex = 1
    currentPlayer = CurrentPlayerList[currentPlayerIndex]
    --currentPlayerColor = currentPlayer.color
    PlayerTurnState = TURN_STATE.Play

    PlayerTurnLoop()

end

function PlayerTurnLoop()
    debug('Enter Turn Loop: '..PlayerTurnState)
    --Turn State Machine
    if PlayerTurnState == TURN_STATE.Respond
    then--Right now, the only cards to 'respond' to are stacking +2 or +4 cards

      --=========================================================================================================================
    elseif PlayerTurnState == TURN_STATE.Play
    then
      if isComputerPlayer(currentPlayer)
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
    elseif PlayerTurnState == TURN_STATE.Decide
    then--Right now, the only cards to 'decide' on are wild card, and 7 or 0 if SevenZero rules are enabled

        --Descision State Machine
        if DescisionState == DESCISION_STATE.Wild
        then--When the player is deciding what color to make a wild card
          if isComputerPlayer(currentPlayer) == false
          then
            UI.setAttribute("WildCardPanel", "active", "true")
            UI.show("WildCardPanel")
            UI.setAttribute("WildCardPanel", "visibility", currentPlayer.color)
          else
            WildPanelButtons(nil,nil,WILDCOLORS[math.random(4)])
          end
        end
        --=========================================================================================================================
    elseif PlayerTurnState == TURN_STATE.End
    then
        --Update the play deck's color
        PlayZoneMattObject.setColorTint(getColorValueFromCard(lastCard.Description))

        debug('Ending Player\'s Turn')
        EndPlayerTurn()
    end
end

--Function called by PlayZoneTrigger: checks if the object entering the zone is a card is a card that is allowed to be played
function CheckPlayedCard(card_played)
    if card_played.held_by_color == currentPlayer.color or card_played.getVar("CopmuterPlayerCard") == true
    then--Check that the card being played is held by the current player
        if lastCard.GUID == nil
        then--Assume that this is the first card being played, if lastCard Object is nil
            return true--The card is allowed to be played
        else
            if card_played.getDescription() == lastCard.Description
            then--Card being played does matches face / color / wild
                return true--The card is allowed to be played
            elseif card_played.getName() == lastCard.Name
            then
                return true--The card is allowed to be played
            elseif card_played.getDescription() == 'WILD'
            then
                return true--The card is allowed to be played
            else--Card being played does not match face / color / wild
                return false--The card is not allowed to be played
            end

        end
    end
end

--Function accepts card from player and adds it to the Draw Deck
function PlayCard(card)
    --update cardPlayed tracker
    cardPlayed = true

    --Update reference to lastCard
    lastCard.GUID = card.getGUID()
    lastCard.Description = card.getDescription()
    lastCard.Name = card.getName()

    --Update individual card variables
    card.setVar('Color_Holding', nil)
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

    --[[ TODO --]]
    --Update PlayDeckObject reference

    --
    PlayerTurnState = TURN_STATE.End
    --...But there are some exceptions to that rule
    if lastCard.Description == "WILD"
    then
        PlayerTurnState = TURN_STATE.Decide
        DescisionState = DESCISION_STATE.Wild
    end
    if lastCard.Name == "reverse"
    then
      clockwise = not clockwise
    end
    PlayerTurnLoop()
end

--Function rejects card from player and sends it back to their hand
function RejectCard(card,message)

    local _player = Player[card.held_by_color]
    card.setPositionSmooth(_player.getHandTransform().position, false, true)
    broadcastToColor(message,_player.color,getColorValueFromPlayer(_player.color))
end

function DrawCardButton(_player)
  if _player.color == currentPlayer.color
  then
    GiveCardsToPlayer(1, _player)
  else
    broadcastToColor("You can only draw cards on your turn", _player.color,getColorValueFromPlayer(_player.color))
  end

end
--Our own function to deal cards to a player, so that we can perform any special actions on cards we need to
function GiveCardsToPlayer(NumberOfCards,PlayerToDeal)

    debug('Dealing '.. NumberOfCards ..' to '.. PlayerToDeal.color)
    for i=1, NumberOfCards do

        local cardDealt
        cardDealt = DrawDeckObject.takeObject({
          position = PlayerToDeal.getHandTransform().position,
          rotation = {PlayerToDeal.getHandTransform().rotation.x,PlayerToDeal.getHandTransform().rotation.y+180,0},
          index = 1,
          smooth = true})

        cardDealt.setVar('Color_Holding', PlayerToDeal)
        cardDealt.setVar('Card_Played', false)

    end
end

function EndPlayerTurn()
  if clockwise == true
  then
    if currentPlayerIndex + 1 > #CurrentPlayerList
    then
        currentPlayerIndex = 1
    else
        currentPlayerIndex = currentPlayerIndex + 1
    end
  else
    if currentPlayerIndex - 1 < 1
    then
      currentPlayerIndex = #CurrentPlayerList
    else
      currentPlayerIndex = currentPlayerIndex - 1
    end
  end

    currentPlayer = CurrentPlayerList[currentPlayerIndex]
    --If no special cases are made, return the Turn state to Play
    PlayerTurnState = TURN_STATE.Play

    if cardPlayed == true
    then--if a card was played this round, check for special cases that would effect the player turn state machine
      if lastCard.Name == "+2" and HouseRules.Stack_Plus2 == true
      then--Check if the last card played requires the next player in turn to make a response
        PlayerTurnState = TURN_STATE.Respond
      elseif lastCard.Name == "+4" and HouseRules.Stack_Plus4 == true
        then--Check if the last card played requires the next player in turn to make a response
          PlayerTurnState = TURN_STATE.Respond
      elseif lastCard.Name == "+2" and HouseRules.Stack_Plus2 == false
      then--Check if the last card played requires the next player in turn to make a response
        debug('Last Card +2 & no stacking - dealing next player 2 cards & ending their turn')
        GiveCardsToPlayer(2,currentPlayer)
        PlayerTurnState = TURN_STATE.End
      elseif lastCard.Name == "+4" and HouseRules.Stack_Plus4 == false
        then--Check if the last card played requires the next player in turn to make a response
          debug('Last Card +4 & no stacking - dealing next player 4 cards & ending their turn')
        GiveCardsToPlayer(4,currentPlayer)
        PlayerTurnState = TURN_STATE.End
      elseif lastCard.Name == "skip"
          then--check if the last card played was a skip card
            debug('Last Card skip. Ending next players turn')
            PlayerTurnState = TURN_STATE.End
      end
    end

    cardPlayed = false --reset the cardPlayed variable


    debug('\n')
    PlayerTurnLoop()
end

--Grab players that are currently seated and populate 'CurrentPlayerList'
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
        then--If a given player is seated
            CurrentPlayerList[counter] = _player--add that player to our reference table, and update our tokenLocations table
            counter = counter + 1
        else
            if isComputerPlayer(_player)
            then
                debug(_player.color .. ' is a CPU')
              CurrentPlayerList[counter] = _player
              counter = counter + 1
            end
        end
    end
end

do--UI Functions
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
    --[[Called by Main Menu buttons to change House Rules]]
    function UpdateDrawingRules(a,opt)
        if opt == "Only draw one card per turn"
        then
            HouseRules.Multi_Draw = false
        elseif opt == "Draw many cards per turn"
        then
            HouseRules.Multi_Draw = true
        end
        debug("Draw Multiple Cards: " .. tostring(HouseRules.Multi_Draw) .. "\n")
    end
    function UpdateStackingRules(a,opt)
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
    function UpdateTurnpassingRules(a,opt)
 
        if opt == "True"
        then
            HouseRules.Pass_Turn = true

        elseif opt == "False"
        then
            HouseRules.Pass_Turn = false
        end
        debug("Turn Passing: ".. tostring(HouseRules.Pass_Turn) .. "\n")
    end
    function UpdateScriptedUnoRules(a,opt)
        if opt == "True"
        then
            HouseRules.Call_Uno = true
        elseif opt == "False"
        then
            HouseRules.Call_Uno = false
        end
        debug("Scipted Uno: ".. tostring(HouseRules.Call_Uno) .. "\n")
    end
    function UpdateSevenZeroRules(a,opt)
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
        if UI.getAttribute("MainMenuPanel", "active") == 'true'
        then
            UI.setAttribute("MainMenuPanel", "active", "false")
            UI.setAttribute("MainMenuContainer", "height", "5%")
            UI.setAttribute("HideMenuButton", "height", "100%")
            UI.setAttribute("HideMenuButton", "text", "Show Main Menu")
        else
            UI.setAttribute("MainMenuPanel", "active", "true")
            UI.setAttribute("MainMenuContainer", "height", "75%")
            UI.setAttribute("HideMenuButton", "height", "5%")
            UI.setAttribute("HideMenuButton", "text", "Hide Main Menu")
        end
    end
end

do--Fake Player Function
    --[[Computer Controlled Player Functions]]
    function isComputerPlayer(PlayertoCheck)
        for i=1, #COMPUTERPLAYERS do
            if COMPUTERPLAYERS[i] == PlayertoCheck
            then
            return true
            end
        end
        return false
    end
    --Place a 'CPU' token in front of each computer controlled player
    function MarkComputerPlayers()
        for i=1, #COMPUTERPLAYERS do
            tempObject = spawnObject({
            type = "PiecePack_Suns",
            position = LABELLOCATIONS[COMPUTERPLAYERS[i].color:upper()],
            rotation = SEATROTATIONS[COMPUTERPLAYERS[i].color:upper()],
            scale = {0.8,0.5,0.8},
            sound = false})
            tempObject.setColorTint(getColorValueFromPlayer(COMPUTERPLAYERS[i].color))
            tempObject.use_gravity = false
            tempObject.rotate({0,180,0})
            tempObject.UI.setXmlTable(
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

    function DoComputerPlayerTurn(_player,cardDrawn)
        debug('Doing CPU turn for '.. _player.color)
        local cardPlayed = false
        for i=1,#_player.getHandObjects()
        do
            local tempCard = _player.getHandObjects()[i]
            tempCard.setVar("CopmuterPlayerCard", true)
            if CheckPlayedCard(tempCard)
            then
                PlayCard(tempCard)
                cardPlayed = true
                break
            end
        end
        if cardPlayed == false
        then
            debug('No card can be played')
            if cardDrawn == false
            then
                GiveCardsToPlayer(1,_player)
                DoComputerPlayerTurn(_player,true)
            else
                EndPlayerTurn()
            end

        end
    end
end

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

function debug(string)
  if debug_mode == true
  then
    log('[DEBUG]  '.. tostring(string))
  end
end