/****************************************************************************************
Name            : QuoteCalculator
Revision Log    : 8/12/2020 Bryan
                :
                :
Use             : Used with the CPQ API, DO NOT UPDATE VARIABLES UNLESS API CHANGES
*****************************************************************************************/
public with sharing class QuoteCalculator {

  public QuoteModel calculate(QuoteModel quote) {
    QuoteCalculatorContext ctx = new QuoteCalculatorContext(quote);
    String quoteJSON = SBQQ.ServiceRouter.load(
      'SBQQ.QuoteAPI.QuoteCalculator',
      null,
      JSON.serialize(ctx)
    );
    return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
  }
  public QuoteModel read(String quoteId) {
    String quoteJSON = SBQQ.ServiceRouter.read(
      'SBQQ.QuoteAPI.QuoteReader',
      quoteId
    );
    return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
  }

  public QuoteModel save(QuoteModel quote) {
    String quoteJSON = SBQQ.ServiceRouter.save(
      'SBQQ.QuoteAPI.QuoteSaver',
      JSON.serialize(quote)
    );
    return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
  }

  public void calculate(QuoteModel quote, String callbackClass) {
    QuoteCalculatorContext ctx = new QuoteCalculatorContext(
      quote,
      callbackClass
    );
    SBQQ.ServiceRouter.load(
      'SBQQ.QuoteAPI.QuoteCalculator',
      null,
      JSON.serialize(ctx)
    );
  }


  public with sharing class QuoteCalculatorContext {
    public QuoteModel quote;
    public String callbackClass;
    public QuoteCalculatorContext(QuoteModel quote, String callbackClass) {
      this.quote = quote;
      this.callbackClass = callbackClass;
    }

    public QuoteCalculatorContext(QuoteModel quote) {
      this.quote = quote;
      this.callbackClass = null;
    }
  }
}