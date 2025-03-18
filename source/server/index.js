const { Client } = require("discord-rpc");
const http = require("node:http");

const CLIENT_ID = "1351607979018813462";
const SERVER_PORT = process.env.PORT || 7000;
const MAX_TIME_BETWEEN_CONNECTION_ATTEMPTS = 30e3; //TODO: Better name.
/*
 * This variable dictates the maximum time between
 * connections to the Discord RPC server.
 */

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

    while (!user) {
        await sleep(sleepTime);

        sleepTime = Math.clamp(
            sleepTime * 2,
            5e3,
            MAX_TIME_BETWEEN_CONNECTION_ATTEMPTS
        );

        try {
            console.log("attempting login");
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
                data = undefined;
            }

            if ((discordClient === null) || (discordClient.user === null)) {
                return;
            }

            if ((!data) || data.requestType === "CLOSE") {
                discordClient.clearActivity().catch();
                endResponse();
                return;
            }
            data.requestType = undefined;

            console.log(data);

            discordClient.setActivity(data);
        } catch (err) {
            console.log(`ERROR: ${err}`);

            discordClient.clearActivity().catch();
        }
    });

    endResponse();
}).listen(SERVER_PORT);
