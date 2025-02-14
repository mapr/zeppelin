package org.apache.zeppelin.rest;

import com.nimbusds.jwt.JWT;
import com.nimbusds.oauth2.sdk.AuthorizationCode;
import com.nimbusds.oauth2.sdk.AuthorizationCodeGrant;
import com.nimbusds.oauth2.sdk.AuthorizationGrant;
import com.nimbusds.oauth2.sdk.ResponseType;
import com.nimbusds.oauth2.sdk.TokenRequest;
import com.nimbusds.oauth2.sdk.TokenResponse;
import com.nimbusds.oauth2.sdk.auth.ClientAuthentication;
import com.nimbusds.oauth2.sdk.auth.ClientSecretBasic;
import com.nimbusds.oauth2.sdk.id.State;
import com.nimbusds.oauth2.sdk.token.AccessToken;
import com.nimbusds.openid.connect.sdk.AuthenticationErrorResponse;
import com.nimbusds.openid.connect.sdk.AuthenticationRequest;
import com.nimbusds.openid.connect.sdk.AuthenticationResponse;
import com.nimbusds.openid.connect.sdk.AuthenticationResponseParser;
import com.nimbusds.openid.connect.sdk.LogoutRequest;
import com.nimbusds.openid.connect.sdk.Nonce;
import com.nimbusds.openid.connect.sdk.OIDCTokenResponse;
import com.nimbusds.openid.connect.sdk.OIDCTokenResponseParser;
import org.apache.shiro.SecurityUtils;
import org.apache.shiro.authc.AuthenticationToken;
import org.apache.shiro.session.Session;
import org.apache.shiro.subject.Subject;
import org.apache.zeppelin.realm.sso.OIDCRealm;
import org.apache.zeppelin.realm.sso.SSOConfiguration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Singleton;
import javax.servlet.http.HttpServletRequest;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.core.Context;
import javax.ws.rs.core.Response;
import javax.ws.rs.core.UriInfo;
import java.net.URI;

@Path("/oidc")
@Singleton
public class OIDCRestApi {

  private static final Logger LOGGER = LoggerFactory.getLogger(OIDCRestApi.class);

  private static final String ATTRIBUTE_PREFIX = "oidc_";
  private static final String STATE_ATTRIBUTE = ATTRIBUTE_PREFIX + "state";
  private static final String NONCE_ATTRIBUTE = ATTRIBUTE_PREFIX + "nonce";
  public static final String LOGOUT_REQUEST_ATTRIBUTE = ATTRIBUTE_PREFIX + "logout_request";

  // After successful login, redirect to home
  private static final String POST_LOGIN_REDIRECT_URL = "/";

  private final boolean isEnabled = SSOConfiguration.IS_ENABLED;
  private final SSOConfiguration ssoConfiguration = isEnabled ? SSOConfiguration.getInstance() : null;

  private static Response badRequestError(String message) {
    return Response.status(Response.Status.BAD_REQUEST).entity(message).build();
  }

  private static Response notEnabledError() {
    return badRequestError("SSO is not enabled on cluster");
  }

  @GET
  @Path("is-enabled")
  public Response isEnabled() {
    return Response.ok(isEnabled).build();
  }

  @GET
  @Path("login")
  public Response login(@Context HttpServletRequest request) {
    if (!isEnabled) {
      return notEnabledError();
    }
    Session session = SecurityUtils.getSubject().getSession();
    State state = new State();
    Nonce nonce = new Nonce();
    session.setAttribute(STATE_ATTRIBUTE, state);
    session.setAttribute(NONCE_ATTRIBUTE, nonce);
    URI callbackUri = URI.create(String.format("%s://%s:%d/api/oidc/callback",
            request.getScheme(), request.getServerName(), request.getServerPort()));
    AuthenticationRequest authenticationRequest =  new AuthenticationRequest.Builder(
            ResponseType.CODE,
            SSOConfiguration.SCOPE,
            ssoConfiguration.getClientID(),
            callbackUri)
            .endpointURI(ssoConfiguration.getOidcProviderMetadata().getAuthorizationEndpointURI())
            .state(state)
            .nonce(nonce)
            .build();
    return Response.seeOther(authenticationRequest.toURI()).build();
  }

  @GET
  @Path("callback")
  public Response callback(@Context HttpServletRequest request,
                           @Context UriInfo uriInfo) {
    if (!isEnabled) {
      return notEnabledError();
    }
    try {
      Subject subject = SecurityUtils.getSubject();
      Session session = subject.getSession();
      AuthenticationResponse authenticationResponse = AuthenticationResponseParser.parse(uriInfo.getRequestUri());

      State state = (State) session.getAttribute(STATE_ATTRIBUTE);
      if (!authenticationResponse.getState().equals(state)) {
        return badRequestError("Authentication response state doesn't match authentication request state");
      }

      if (authenticationResponse instanceof AuthenticationErrorResponse) {
        return badRequestError(authenticationResponse.toErrorResponse().getErrorObject().toString());
      }

      AuthorizationCode code = authenticationResponse.toSuccessResponse().getAuthorizationCode();
      AuthorizationGrant codeGrant = new AuthorizationCodeGrant(code, authenticationResponse.getRedirectionURI());
      ClientAuthentication clientAuthentication = new ClientSecretBasic(ssoConfiguration.getClientID(), ssoConfiguration.getClientSecret());
      URI tokenEndpoint = ssoConfiguration.getOidcProviderMetadata().getTokenEndpointURI();
      TokenRequest tokenRequest = new TokenRequest(tokenEndpoint, clientAuthentication, codeGrant, SSOConfiguration.SCOPE);
      TokenResponse tokenResponse = OIDCTokenResponseParser.parse(tokenRequest.toHTTPRequest().send());

      if (!tokenResponse.indicatesSuccess()) {
        return badRequestError(tokenResponse.toErrorResponse().getErrorObject().toString());
      }

      OIDCTokenResponse successResponse = (OIDCTokenResponse)tokenResponse.toSuccessResponse();
      JWT idToken = successResponse.getOIDCTokens().getIDToken();
      AccessToken accessToken = successResponse.getOIDCTokens().getAccessToken();
      Nonce expectedNonce = (Nonce) session.getAttribute(NONCE_ATTRIBUTE);
      session.setAttribute(LOGOUT_REQUEST_ATTRIBUTE, new LogoutRequest(
              ssoConfiguration.getOidcProviderMetadata().getEndSessionEndpointURI(), idToken));
      AuthenticationToken authenticationToken = new OIDCRealm.Token(idToken, expectedNonce, accessToken);
      subject.login(authenticationToken);
    } catch (Exception e) {
      LOGGER.error("Failed to handle OIDC callback", e);
      return badRequestError("OIDC Authentication failed. Please check server logs for details");
    }
    return Response.seeOther(URI.create(POST_LOGIN_REDIRECT_URL)).build();
  }
}
