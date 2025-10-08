import { ApolloServer } from "@apollo/server";
import { startStandaloneServer } from "@apollo/server/standalone";
const typeDefs = `#graphql
  type Query {
    hello: String
  }
`;

const resolvers = {
  Query: {
    hello: () => "Hello world!",
  },
};

const port = process.env.PORT || 3000;

const server = new ApolloServer({ 
  typeDefs, 
  resolvers 
});

await startStandaloneServer(server, {
  listen: { port: Number(port) },
});

console.log(`🚀  Server ready at: http://localhost:${port}/graphql`);
