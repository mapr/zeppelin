package org.apache.zeppelin.livy.maprsecurity;

import com.mapr.security.client.ClientSecurity;
import com.mapr.security.client.MapRClientSecurityException;

import org.apache.hc.client5.http.auth.AuthChallenge;
import org.apache.hc.client5.http.auth.AuthScheme;
import org.apache.hc.client5.http.auth.AuthenticationException;
import org.apache.hc.client5.http.auth.CredentialsProvider;
import org.apache.hc.core5.http.HttpHost;
import org.apache.hc.core5.http.HttpRequest;
import org.apache.hc.core5.http.protocol.HttpContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.security.Principal;

class MaprSecurityScheme implements AuthScheme {

  private static final Logger logger = LoggerFactory.getLogger(MaprSecurityScheme.class);

  public static final String NAME = "MAPR-Negotiate";

  public String getName() {
    return NAME;
  }

  public boolean isConnectionBased() {
    return true;
  }

  public void processChallenge(AuthChallenge authChallenge, HttpContext context) {
      /* Is this play some role in MAPR-Negotiation at all?
       * In case of Kerberos the value of this challenge might be handled in
       * authenticate() when state == CHALLENGE_RECEIVED.
       * But in MARP-Negotiation it's always empty, so we never use it.
       */
  }

  public boolean isChallengeExpected() {
    return false;
  }

  public boolean isChallengeComplete() {
    return true;
  }

  public String getRealm() {
    return null;
  }

  public boolean isResponseReady(HttpHost host, CredentialsProvider credProvider,
                                 HttpContext context) {
    return true;
  }

  public Principal getPrincipal() {
    return null;
  }

  public String generateAuthResponse(HttpHost host, HttpRequest request, HttpContext context)
          throws AuthenticationException {
    ClientSecurity cs = new ClientSecurity();
    String challenge;
    try {
      challenge = cs.generateChallenge();
      logger.info("MaprSecurity challenge generated successfully");
    } catch (MapRClientSecurityException e) {
      throw new AuthenticationException(getName() + " authentication has failed", e);
    }
    return NAME + " " + challenge;
  }
}
