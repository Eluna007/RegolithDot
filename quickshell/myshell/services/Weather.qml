pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string temperature: "--"
    property string description: "--"
    property string feelsLike: "--"
    property string humidity: "--"
    property string city: "Los Angeles"

    readonly property string icon: {
        const d = description.toLowerCase()
        if (d.includes("sunny") || d.includes("clear"))       return "󰖙"
        if (d.includes("partly cloudy"))                       return "󰖕"
        if (d.includes("cloudy") || d.includes("overcast"))   return "󰖐"
        if (d.includes("rain") || d.includes("drizzle"))      return "󰖗"
        if (d.includes("snow"))                                return "󰖘"
        if (d.includes("thunder") || d.includes("storm"))     return "󰖓"
        if (d.includes("fog") || d.includes("mist"))          return "󰖑"
        return "󰖙"
    }

    Process {
        id: poller
        command: ["curl", "-s", "wttr.in/" + root.city.replace(" ", "+") + "?format=j1"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const d = JSON.parse(data)
                    const c = d.current_condition[0]
                    root.temperature  = c.temp_F + "°F"
                    root.feelsLike    = c.FeelsLikeF + "°F"
                    root.humidity     = c.humidity + "%"
                    root.description  = c.weatherDesc[0].value
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: poller.running = true
    }
}
