module.exports = (Module) ->

    analyze = require('Sentimental').analyze
    _ = require 'lodash'
    color = require 'irc-colors'

    people = {}

    thresholds = [
        {name: "hateful", value: -1500}
        {name: "vitriolic", value: -1000}
        {name: "hostile", value: -500}
        {name: "disrespectful", value: -250}
        {name: "mean", value: -100}
        {name: "angry", value: -50}
        {name: "upset", value: -25}
        {name: "neutral", value: 0}
        {name: "happy", value: 25}
        {name: "pleasant", value: 50}
        {name: "kind", value: 100}
        {name: "respectful", value: 250}
        {name: "sophisticated", value: 500}
        {name: "uplifting", value: 1000}
        {name: "saintly", value: 1500}
    ]
    
    class MoodModule extends Module
        shortName: "Mood"
        helpText:
            default: "Analyze the mood of the chatroom and yourself!"
        usage:
            default: "mood"

        updateMood: (server, key, scoreMod, callback = ->) ->
            @db.findAndModify
                server: server
                key: key
              ,
                {}
              ,
                $inc:
                    mood: scoreMod
              ,
                upsert: true
              , (e, doc) -> callback doc

        getTagForScore: (score) ->
            (_.findWhere thresholds, value: _.reduce thresholds, (prev, cur) ->
                if Math.abs(cur.value - score) < Math.abs(prev - score) then cur.value else prev
            , 0).name
    
        constructor: (moduleManager) ->
            super(moduleManager)

            @db = @newDatabase 'moods'
    
            @addRoute "mood me", (origin, route) =>
                [bot, user] = [origin.bot, origin.user]
                @db.find
                    server: bot.getServer()
                    key: user
                , (e, doc) =>
                    @reply origin, "#{user}, I think you are #{color.bold @getTagForScore doc[0].mood}."
    
            @addRoute "mood", (origin, route) =>
                [bot, user, channel] = [origin.bot, origin.user, origin.channel]
                @db.find
                    server: bot.getServer()
                    key: channel
                , (e, doc) =>
                    @reply origin, "#{user}, I think #{channel} is #{color.bold @getTagForScore doc[0].mood}."

            @on 'message', (bot, sender, channel, message) =>
                moduleManager.canModuleRoute @, bot.getServer(), channel, no, =>

                    change = analyze message
                    scoreMod = change.score
                    return if scoreMod is 0

                    callback = (isUser, doc) =>
                        curScore = doc.value.mood
                        oldValue = curScore - scoreMod
                        oldTag = @getTagForScore oldValue
                        newTag = @getTagForScore curScore

                        return if oldTag is newTag

                        bot.say channel, "The channel mood is now: #{color.bold newTag}" unless isUser
                        bot.say channel, "#{doc.value.key}, you are now considered #{color.bold newTag}." if isUser

                    @updateMood bot.getServer(), sender, scoreMod, callback.bind @, yes
                    @updateMood bot.getServer(), channel, scoreMod, callback.bind @, no
    
    
    MoodModule
