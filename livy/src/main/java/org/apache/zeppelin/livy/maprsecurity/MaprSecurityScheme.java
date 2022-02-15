package org.apache.zeppelin.livy.maprsecurity;

import com.mapr.security.client.MapRClientSecurityException;
import org.apache.http.Header;
import org.apache.http.HttpRequest;
import org.apache.http.auth.AuthenticationException;
import org.apache.http.auth.Credentials;
import org.apache.http.auth.MalformedChallengeException;
import org.apache.http.impl.auth.AuthSchemeBase;
import org.apache.http.message.BasicHeader;
import org.apache.http.util.Args;
import org.apache.http.util.CharArrayBuffer;

import com.mapr.security.client.ClientSecurity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

class MaprSecurityScheme extends AuthSchemeBase {

  private static final Logger logger = LoggerFactory.getLogger(MaprSecurityScheme.class);

  public static final String NAME = "MAPR-Negotiate";

  private boolean isComplete = false;

  protected void parseChallenge(
          CharArrayBuffer buffer, int beginIndex, int endIndex) throws MalformedChallengeException {
    /* Is this play some role in MAPR-Negotiation at all?
     * In case of Kerberos the value of this challenge might be handled in
     * authenticate() when state == CHALLENGE_RECEIVED.
     * But in MARP-Negotiation it's always empty, so we never use it.
     */
    // final String challenge = buffer.substringTrimmed(beginIndex, endIndex);
    // byte[] parsedChallenge = Base64.decodeBase64(challenge.getBytes());
  }

  public String getSchemeName() {
    return NAME;
  }

  public String getParameter(String name) {
    Args.notNull(name, "Parameter name");
    return null;
  }

  public String getRealm() { return null; }

  public boolean isConnectionBased() { return true; }

  public boolean isComplete() { return isComplete; }

  public Header authenticate(
          Credentials credentials, HttpRequest request) throws AuthenticationException {
    ClientSecurity cs = new ClientSecurity();
    String challenge;
    try {
      challenge = cs.generateChallenge();
      logger.info("Chalange {}", challenge);
    } catch (MapRClientSecurityException e) {
      throw new AuthenticationException(getSchemeName() + " authentication has failed", e);
    }
    isComplete = true;
    return new BasicHeader("Authorization", NAME + " " + challenge);
  }
}
