record TransactionResponse {
  result : Transaction,
  status : String
}

component Send {
  connect Application exposing { walletInfo }
  connect WalletStore exposing { currentWallet }

  fun componentDidMount : Promise(Never, Void) {
    if (Maybe.isNothing(currentWallet)) {
      Window.navigate("/login")
    } else {
      Promise.never()
    }
  }

  state sendError : String = ""
  state currentTransaction : Maybe(Transaction) = Maybe.nothing()

  state address : String = ""
  state amount : String = ""

  state amountError : String = ""

  fun onAddress (event : Html.Event) {
    next { address = Dom.getValue(event.target) }
  }

  fun onAmount (event : Html.Event) : Promise(Never, Void) {
    next { amount = value }
  } where {
    value =
      Dom.getValue(event.target)
  }

  fun validateAmount (value : String, tokens : Array(Token)) : String {
    try {
      amt =
        Number.fromString(value)
        |> Maybe.withDefault(0)

      sushi =
        tokens
        |> Array.find((token : Token) : Bool { token.name == "SUSHI" })
        |> Maybe.map((token : Token) : Maybe(Number) { Number.fromString(token.amount) })
        |> Maybe.flatten
        |> Maybe.withDefault(0)

      if (sushi <= (amt + 0.0001)) {
        "You don't have enough SUSHI to send"
      } else if (amt <= 0) {
        "you must supply an amount greater than 0"
      } else {
        ""
      }
    }
  }

  fun sendTransaction (event : Html.Event) : Promise(Never, Void) {
    sequence {
      wi =
        walletInfo

      cw =
        currentWallet
        |> Maybe.toResult("Could not get current wallet")

      unsignedTransaction =
        createUnsignedTransaction(wi, cw)

      postUnsignedTransaction(unsignedTransaction)

      txn =
        currentTransaction
        |> Maybe.toResult("Could not get current transaction")

      `console.log('HERE')`
      `console.log(#{txn})`  

      postSignedTransaction(txn, cw)
    } catch {
      next { sendError = "Could not parse json response" }
    }
  }

  fun compactJson (value : String) : String {
    `JSON.stringify(JSON.parse(#{value}, null, 0)) `
  }

  fun postUnsignedTransaction (transaction : Transaction) : Promise(Never, Void) {
    sequence {
      encodedTransaction =
        encode transaction

      response =
        Http.post("http://localhost:3001/api/v1/transaction/unsigned")
        |> Http.stringBody(
          compactJson(Json.stringify(encodedTransaction)))
        |> Http.send()

      json =
        Json.parse(response.body)
        |> Maybe.toResult("Json parsing error")

      item =
        decode json as TransactionResponse

      txn =
        item.result

      next { currentTransaction = Maybe.just(txn) }
    } catch Http.ErrorResponse => er {
      next { sendError = "Could not retrieve remote wallet information" }
    } catch String => er {
      next { sendError = "Could not parse json response" }
    } catch Object.Error => er {
      next { sendError = "could not decode json" }
    }
  }

  fun postSignedTransaction (transaction : Transaction, wallet : Wallet) : Promise(Never, Void) {
    sequence {
      signingKey =
        Sushi.Wallet.getPrivateKeyFromWif(wallet.wif)

      transactionToSign =
        currentTransaction
        |> Maybe.toResult("Error - can't get transaction to sign")

      signedTransaction =
        Sushi.Wallet.signTransaction(
          signingKey,
          transactionToSign)

      encodedTransaction =
        encode signedTransaction

      response =
        Http.post("http://localhost:3001/api/v1/transaction")
        |> Http.stringBody(
          compactJson(Json.stringify(encodedTransaction)))
        |> Http.send()

      json =
        Json.parse(response.body)
        |> Maybe.toResult("Json parsing error")

      item =
        decode json as TransactionResponse

      txn =
        item.result

      next { currentTransaction = Maybe.just(txn) }
    } catch Http.ErrorResponse => er {
      next { sendError = "Could not retrieve remote wallet information" }
    } catch String => er {
      next { sendError = "Could not parse json response" }
    } catch Object.Error => er {
      next { sendError = "could not decode json" }
    } catch Wallet.Error => er {
      next { sendError = "Error with wallet" }
    }
  }

  fun createUnsignedTransaction (walletInfo : WalletInfo, senderWallet : Wallet) : Transaction {
    {
      id = "",
      action = "send",
      senders =
        [
          {
            address = walletInfo.address,
            publicKey = senderWallet.publicKey,
            amount = amount,
            fee = "0.0001",
            signr = "0",
            signs = "0"
          }
        ],
      recipients =
        [
          {
            address = address,
            amount = amount
          }
        ],
      message = "",
      token = "SUSHI",
      prevHash = "0",
      timestamp = 0,
      scaled = 1
    }
  }

  fun render : Html {
    <Layout
      navigation=[<Navigation current="send"/>]
      content=[renderPageContent]/>
  }

  get renderPageContent : Html {
    walletInfo
    |> Maybe.map(pageContent)
    |> Maybe.withDefault(loadingPageContent)
  }

  get loadingPageContent : Html {
    <div>
      "LOADING"
    </div>
  }

  fun pageContent (walletInfo : WalletInfo) : Html {
    <div class="row">
      <div class="col-md-12">
        <div/>

        <div class="row">
          <div class="col-md-3">
            <WalletBalances
              address={walletInfo.address}
              readable={walletInfo.readable}
              tokens={walletInfo.tokens}/>
          </div>

          <div class="col-md-9">
            <div class="card border-dark mb-3">
              <div class="card-body">
                <h4 class="card-title">
                  "Send tokens"
                </h4>

                <div>
                  <div class="form-row mb-3">
                    <div class="col-md-8 mb-6">
                      <label for="recipient-address">
                        "Recipient address (or human readable address)"
                      </label>

                      <input
                        type="text"
                        class="form-control"
                        id="recipient-address"
                        placeholder="Recipient address"
                        onInput={onAddress}
                        value={address}/>

                      <div class="valid-feedback">
                        "Looks good!"
                      </div>
                    </div>
                  </div>

                  <div class="form-row">
                    <div class="col-md-4 mb-3">
                      <label for="amount-to-send">
                        "Amount to send"
                      </label>

                      <input
                        type="text"
                        class="form-control"
                        id="amount-to-send"
                        placeholder="Amount to send"
                        onInput={onAmount}
                        value={amount}/>

                      <div class="valid-feedback">
                        "Looks good!"
                      </div>
                    </div>

                    <div class="col-md-4 mb-3">
                      <label for="token-to-send">
                        "Token"
                      </label>

                      <input
                        type="text"
                        class="form-control"
                        id="token-to-send"
                        placeholder="SUSHI"/>

                      <div class="invalid-feedback">
                        "Please choose a username."
                      </div>
                    </div>
                  </div>

                  <div class="form-group">
                    <div class="form-check">
                      <input
                        class="form-check-input"
                        type="checkbox"
                        value=""
                        id="invalidCheck"/>

                      <label
                        class="form-check-label"
                        for="invalidCheck">

                        "Agree to terms and conditions"

                      </label>

                      <div class="invalid-feedback">
                        "You must agree before submitting."
                      </div>
                    </div>
                  </div>

                  <button
                    onClick={sendTransaction}
                    class="btn btn-secondary"
                    type="submit">

                    "Send"

                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  }
}
