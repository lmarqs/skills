import { Client } from "@elastic/elasticsearch";
import { Product, SearchIndex } from "../core/ports";

export class ElasticSearchIndex implements SearchIndex {
  constructor(private readonly client: Client, private readonly indexName: string) {}

  async put(product: Product): Promise<void> {
    await this.client.index({ index: this.indexName, id: product.id, document: product });
  }

  async clear(): Promise<void> {
    await this.client.deleteByQuery({ index: this.indexName, query: { match_all: {} } });
  }
}
