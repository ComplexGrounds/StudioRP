import { Client } from "discord-rpc";
import http from "node:http";

const CLIENT_ID = "1310621078007054477";
const SERVER_PORT = process.env.PORT || 7000;
const MAX_SLEEP = 30e3;

Math.clamp = function(number, min, max) {
    return Math.min(Math.max(number, min), max)
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
}

async function loginToDiscord(client) {
    let user;
    try {
        let loginPromise = await client.login({
            clientId: CLIENT_ID
        });
        user = loginPromise.user;
        console.log((user && user.username) || user)
    } finally { }

    return user
}

async function start(client) {
    let user;

    let sleepTime = 0;

    while (!user) {
        await sleep(sleepTime);

        sleepTime = Math.clamp(sleepTime * 2, 5e3, MAX_SLEEP);

        try {
            console.log("attempting login")
            user = await loginToDiscord(client);
        } catch { }
    }
}

const discordClient = new Client({ transport: "ipc" });

start(discordClient);

http.createServer((request, response) => {
    console.log("New request!")
    let data = "";

    function endResponse() {
        if (response.destroyed) {
            return;
        }

        response.writeHead(200, { "Content-Type": "text/plain" });
        response.end("SET Activity");
    };

    request.on("data", (chunk) => {
        data += chunk;
        console.log(data)
        if (data.length > 1e6) {
            console.log("Too much data! Closing.")
            request.destroy();
        }
    });

    request.on("end", () => {
        try {
            try {
                data = JSON.parse(data);
            } catch (e) {
                data = undefined;
            }

            if ((!data) || data.State === "STOP") { // change from updateType to something descriptive
                discordClient.clearActivity().catch();
                endResponse();
                return;
            }

            discordClient.setActivity(data);
        } catch (err) {
            console.error(err);

            discordClient.clearActivity().catch(() => {
                console.error("Failed to clear activity!");
            });
        }
    });

    endResponse();
}).listen(SERVER_PORT);
