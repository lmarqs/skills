import express from "express";
import { Client } from "@elastic/elasticsearch";
import { reindexCatalog } from "../core/reindexCatalog";
import { ElasticSearchIndex } from "../adapters/elasticIndex";
import { PostgresProductStore } from "../adapters/postgresProductStore";
import { pool } from "./db";

const app = express();

app.post("/admin/reindex", async (_req, res) => {
  const store = new PostgresProductStore(pool);
  const index = new ElasticSearchIndex(new Client({ node: process.env.ES_URL! }), "products");
  const count = await reindexCatalog(store, index);
  res.json({ reindexed: count });
});

app.listen(3000);
