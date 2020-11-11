String [] results = DataFactory.loadData();
for (Integer i= 0; i < results.size(); i++) {
    DataFactory.QuoteToBundle qb = (DataFactory.QuoteToBundle)JSON.deserialize(results[i], DataFactory.QuoteToBundle.class);
    DataFactoryQuoteCalculator dfqq = new DataFactoryQuoteCalculator(qb.quoteId, qb.priceBookId, qb.productId);
}