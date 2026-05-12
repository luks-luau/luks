# Discord Standard Library (`luks-std/Discord`)

An Enterprise Object-Oriented Discord API framework built purely in Luau for the **luks-luau** runtime engine.

## Overview

Designed for maximum performance, robustness, and expressive Object-Oriented syntax, `luks-std/Discord` abstracts raw networking details into rich entity models while preserving zero-cost asynchronous integration.

### Enterprise Features

- **Pure Object-Oriented API (OOP):** Receive rich entities (`Message`, `User`, `Guild`, `Channel`, `Member`, `Interaction`, `ThreadChannel`, `VoiceState`) exposing actionable native helper methods like `message:reply()`, `message:edit()`, `member:timeout()`, and `guild:leave()`.
- **Fluent UI Component Builders:** Chainable constructor patterns supporting advanced user interfaces (`ActionRowBuilder`, `ButtonBuilder`, `StringSelectMenuBuilder`, `TextInputBuilder`, `ModalBuilder`).
- **Stateful Interaction Routing:** Respond to webhooks effortlessly using `interaction:reply()`, `interaction:deferReply()`, `interaction:showModal()`, or read user input securely via `interaction:getTextInputValue()`.
- **Dynamic Threading & Audio States:** Instantiate forum/thread sub-channels via `message:startThread()` and command audio connectivity using `client:joinVoiceChannel()`.
- **Bitwise Intents via `bit32`:** Full compile-safe integer handling leveraging the runtime's native `bit32` instructions.
- **Persistent Heap Protection:** Automated active observer detachment and resource reclamation protocols ensuring high-volume connection resets never duplicate closures or leak heap memory.

## Quickstart

```lua
local Discord = require("luks-std/Discord")
local Client = Discord.Client
local Embed = Discord.Embed
local Components = Discord.Components
local Intents = Discord.Data.Intents

-- Instantiate the bot client enabling bitwise Intents composition
local client = Client.new({
    token = "YOUR_TOKEN_HERE",
    intents = Intents.create(Intents.Guilds, Intents.GuildMessages, Intents.MessageContent)
})

-- Listen to strongly typed lifecycle Signals
client.onReady:Connect(function(user)
    print("Bot Logged in as:", user.username)
    print("Official mention syntax:", user:mention())
end)

-- Handle standard text messages using object-oriented abstractions
client.onMessageCreate:Connect(function(message)
    -- Ignore bot messages to avoid infinite feedback loops
    if message.author.bot then return end

    if message.content == "!premium" then
        -- Advanced method chaining for Embed generation
        local embed = Embed.new()
            :setTitle("Enterprise Architecture Completed!")
            :setDescription("Responded with total fluidity using pure OOP design patterns.")
            :setColor("#00ffcc")
            :setFooter("Powered by Luks-Luau", message.author:avatarUrl())

        -- Native reply method frames payloads and manages background HTTP streams
        local ok, response = message:reply({ embeds = { embed } })
        
        if ok and response then
            print("Response successfully delivered under ID:", response.id)
            task.wait(2)
            response:edit("Message edited remotely via chainable OOP wrapper!")
        end
    end
end)

-- Handle application interactions (Slash Commands, Buttons, Modals)
client.onInteractionCreate:Connect(function(interaction)
    if interaction.type == 2 then -- Slash Command
        if interaction.data and interaction.data.name == "feedback" then
            local txtInput = Components.TextInputBuilder()
                :setCustomId("reason")
                :setLabel("Why do you love Luau?")
                :setStyle("Paragraph")
                :setRequired(true)

            local row = Components.ActionRowBuilder():addComponents(txtInput)
            local modal = Components.ModalBuilder()
                :setCustomId("modal_feedback")
                :setTitle("User Feedback Form")
                :addComponents(row)

            interaction:showModal(modal)
        end
    elseif interaction.type == 5 then -- Modal Submit
        if interaction.data and interaction.data.custom_id == "modal_feedback" then
            local answer = interaction:getTextInputValue("reason") or "No input"
            interaction:reply({
                content = "Thank you for your feedback: `" .. answer .. "`",
                ephemeral = true
            })
        end
    end
end)

-- Connect and trigger the core Gateway loop
client:login()
```

## Structure Reference

### Entities Exported
- `Client`: Top-level orchestration module.
- `Embed`: Chainable output schema builder.
- `Components`: Standard component factory interfaces.
- `VoiceState`: Active voice connection details tracker.
- `ThreadChannel`: Forum branch manipulation framework.
- `Data.Intents`: Registry containing all bitwise gateway intents.

### Automatic Reconnect & Resource Recovery
If socket execution aborts due to external network conditions, the gateway layer actively detaches lingering signals from memory loops to protect heap depth before performing incremental interval reconnect handshakes.
