import { ApolloServer } from "@apollo/server";
import { expressMiddleware } from "@as-integrations/express5";
import cors from "cors";
import http from "http";
import express from "express";
import { ApolloServerPluginDrainHttpServer } from "@apollo/server/plugin/drainHttpServer";
import { readFileSync } from "fs";
import { resolvers } from "./resolvers";

const app = express();
const httpServer = http.createServer(app);
const typeDefs = readFileSync('./schema.graphql', 'utf8');

const server = new ApolloServer({
  typeDefs,
  resolvers,
  plugins: [ApolloServerPluginDrainHttpServer({ httpServer })],
});

await server.start();

app.use(
  '/graphql',
  cors<cors.CorsRequest>(),
  express.json(),
  expressMiddleware(server, {
    context: async ({ req }) => ({ token: req.headers.token }),
  }),
);

app.get('/api/auth/callback', async (req, res) => {
  let code = req.query.code;
  if (Array.isArray(code)) code = code[0];
  if (typeof code !== 'string' || !code) {
    return res.redirect(`${process.env.FRONTEND_URL}?error=missing_code`);
  }

  const params = new URLSearchParams();
  params.append('grant_type', 'authorization_code');
  params.append('code', code);
  if (process.env.REDIRECT_URL) params.append('redirect_uri', process.env.REDIRECT_URL);

  const basicAuth = Buffer.from(
    `${process.env.DISCORD_CLIENT_ID}:${process.env.DISCORD_CLIENT_SECRET}`
  ).toString('base64');

  try {
    const tokenResponse = await fetch('https://discord.com/api/oauth2/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': `Basic ${basicAuth}`
      },
      body: params.toString() // ou juste `params`
    });

    const text = await tokenResponse.text(); // lire le body pour debug
    if (!tokenResponse.ok) {
      console.error('Discord token error', tokenResponse.status, text);
      return res.status(tokenResponse.status).send(text);
    }

    const data = JSON.parse(text);
    // data contient access_token, refresh_token, expires_in, etc.
    res.redirect(`${process.env.FRONTEND_URL}?access_token=${data.access_token}&refresh_token=${data.refresh_token}`);
  } catch (err) {
    console.error(err);
    res.status(500).send('Token exchange failed');
  }
});

const port = process.env.PORT || 3000;
app.listen(Number(port), () => {
  console.log(`Server is running on http://localhost:${port}/graphql`);
});
