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


const port = process.env.PORT || 3000;
await new Promise<void>((resolve) => httpServer.listen({ port: port }, resolve));

console.log(`🚀  Server ready at: http://localhost:${port}`);
