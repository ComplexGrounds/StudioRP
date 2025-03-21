const { Client } = require("discord-rpc");
const http = require("node:http");

const CLIENT_ID = "1351607979018813462";
const SERVER_PORT = process.env.PORT || 7000;
const MAX_DISCORD_CONNECTION_INTERVAL = 30e3;

let lastRequestTimestamp = 0;
let clientRequestInterval = 30;

Math.clamp = function(number, min, max) {
    return Math.min(Math.max(number, min), max);
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function loginClient(client) {
    let user;
    try {
        let loginPromise = await client.login({
            clientId: CLIENT_ID
        });
        user = loginPromise.user;
        if (user) {
            console.log(user.username);
        }
    } catch { }

    return user;
}

async function startClient(client) {
    let user;

    let sleepTime = 0;
    let attempt = 0;

    while (!user) {
        await sleep(sleepTime);

        sleepTime = Math.clamp(
            sleepTime * 2,
            5e3,
            MAX_DISCORD_CONNECTION_INTERVAL
        );

        attempt++;

        try {
            console.log(`Login attempt ${attempt}`);
            user = await loginClient(client);
        } catch { }
    }
}

const discordClient = new Client({ transport: "ipc" });

startClient(discordClient);

discordClient.on("disconnected", () => {
    console.log("Disconnected! Attempting reconnection...");
    startClient(discordClient);
});

//TODO: sync this interval with the clientTimeoutInterval changing;
//      using clearInterval and such
setInterval(() => {
    if (lastRequestTimestamp === 0) {
        return;
    }

    if ((Date.now() - lastRequestTimestamp) > (clientRequestInterval * 1e3)) {
        discordClient.clearActivity().catch();
    }
}, clientRequestInterval * 1e3);

http.createServer((request, response) => {
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

        if (data.length > 1e6) {
            console.log("Too much data! Closing.");
            request.destroy();
        }
    });

    request.on("end", () => {
        try {
            try {
                data = JSON.parse(data);
            } catch {
                data = null;
            }

            if ((discordClient === null) || (discordClient.user === null)) {
                response.destroy();
                return;
            }

            if ((!data) || data.requestType === "CLOSE") {
                discordClient.clearActivity().catch();
                endResponse();
                return;
            }

            if (
                data.requestInterval
                && data.requestInterval > clientRequestInterval
            ) {
                clientRequestInterval = data.requestInterval;
                delete data.requestInterval;
            }

            if (data.requestType === "HELLO") {
                lastRequestTimestamp = Date.now();
                return;
            }
            delete data.requestType;

            discordClient.setActivity(data);
            lastRequestTimestamp = Date.now();
        } catch (err) {
            console.log(`ERROR: ${err}`);

            discordClient.clearActivity().catch();
        }
    });

    endResponse();
}).listen(SERVER_PORT);
