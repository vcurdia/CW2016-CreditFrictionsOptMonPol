function varargout=LQSolveREE(LQmat,LQk_t,NumPrecision,isReduce)

% LQSolveREE
%
% This function uses the LQ approximation method proposed by Benigno and
% Woodford (2008) to solve for optimal policy.
% 
% Usage:
%
%   REE=LQSolveREE(LQmat,LQk_t,NumPrecision)
%   [REE,LQz_t]=LQSolveREE(LQmat,LQk_t,NumPrecision)
%
% Inputs:
%   - LQmat: structure with numerical matrices for the LQ approx
%   - LQk_t: symbolic vector with full list of state space variables
%     generated by LQ function
%   - NumPrecision: (optional) numerical precision to evaluate the SOC. If
%     ommitted it is set to 1e-6.
%   - isReduce: (optional) logical switch, if set to 1 it reduces the
%     solution as much as possible including eliminating the multipliers.
%     Otherwise it does not reduce the system. Default: 1
%
% Outputs:
%   - REE: structure with the following fields:
%     * Phi1 and Out.Phi2: matrices for the REE solution such that:
%         z_t = Phi1*z_tL + Phi2*eps_t
%       with
%         z_t = (ly_t,csi_t)
%       NOTICE: if system fails to reduce then the above system is defined
%       interms of z_t = (ly_t,csi_t,GLM_t)
%     * REE.z_t: list of state space variables in reduced system
%     * REE.eu: gensys return code
%     * REE.Sy: selection matrix for endogenous variables
%     * REE.Scsi: selection matrix for exogenous variables
%     * REE.Svphi: selection matrix for lagrange multipliers of forward
%         looking constraints
%   - LQz_t: (only if nargout=2) the same as REE.z_t
%
% The code will issue a warning message if the solution to the REE is not
% normal in any way.
%
% Required Matlab routines:
%   - Symbolic Toolbox
%   - LQ.m
%   - gensys.m, by Chris Sims, available in his website
%   
% See also:
% LQ, LQSolveREE, LQCheckSOC, LQCheckSOCold, LQGenSymVar, LQAltRule, 
% LQWEval, MonFrictions, MonFrictionsIRFPlot, MonFrictionsIRFPlotComp, 
% MonFrictionsIRFPlotAltRule, SmetsWouters
%   
% .........................................................................
%
% Copyright 2004-2009 by Filipo Altissimo, Vasco Curdia and Diego Rodriguez 
% Palenzuela.
% Created: July 26, 2004
% Updated: September 18, 2009

% -------------------------------------------------------------------------

% The previous information above can be accessed issuing the following
% command:
%    help LQSolveREE
% or
%    doc LQSolveREE

%% ------------------------------------------------------------------------

%% Setup some background information

if nargin<3, NumPrecision = 1e-6; end
if nargin<4, isReduce = true; end

ny = size(LQmat.A0,1);
nF = size(LQmat.C0,1);
nG = size(LQmat.D0,1);
ncsi = size(LQmat.B0,2);
nk = ny+ncsi+nF+nG+ny+ncsi+nG;

G0 = LQmat.G0;
G1 = LQmat.G1;
G2 = LQmat.G2;
G3 = LQmat.G3;

%% ------------------------------------------------------------------------

%% Solve the REE using gensys
% Check to see if there are any A0 rows corresponding to the FOC with
% no expectations, due to the parameter values used (even if symbolically
% they could be non-zero)
cv = find(all(G0(1:ny,:)==0,2)~=0);
G0(cv,:) = -G1(cv,:);
G1(cv,:) = 0;
G3(:,cv) = [];

% In this framework const is set to zero
const = zeros(nk,1);

[B1,Const,B2,fmat,fwt,ywt,gev,eu] = gensys(G0,G1,const,G2,G3);

if any(eu~=1)
    fprintf('Warning: eu = (%.0f,%.0f)',eu)
    if all(eu)==-2
        fprintf(' - Coincident zeros!!!')
    elseif eu(1)~=1
        fprintf(' - Solution does not exist!!!')
    elseif eu(2)~=1
        fprintf(' - Solution is not unique!!!')
    end
    fprintf('\n')
end

%% Reduce solution
if isReduce
    % The solution is now in the form:
    %   k_t = B1*k_tL + B2*eps_t
    % We want to convert it to the form:
    %   x_t = C1*x_tL + C2*eps_t
    % where
    %   k_t = (hy_t,csi_t,FLM_t,GLM_t,hyL_t,csiL_t,GLML_t)
    %   x_t = (hy_t,csi_t,GLM_t)
    C1 = B1(1:ny+ncsi+nF+nG,1:ny+ncsi+nF+nG);
    C1(:,ny+ncsi+1:ny+ncsi+nF)=[];
    C1(ny+ncsi+1:ny+ncsi+nF,:)=[];
    C2 = [B2(1:ny+ncsi,:);B2(ny+ncsi+nF+1:ny+ncsi+nF+nG,:)];
    % fprintf('State space includes GLM_t.\n')
    Phi1 = C1;
    Phi2 = C2;
    LQz_t = LQk_t([1:ny+ncsi,ny+ncsi+nF+(1:nG)]);
    Phi_vphi_z = Phi1(ny+ncsi+(1:nG),1:ny+ncsi);
    Phi_vphi_vphi = Phi1(ny+ncsi+(1:nG),ny+ncsi+(1:nG));
    Phi_vphi_eps = Phi2(ny+ncsi+(1:nG),:);

    % We want to convert it to the form:
    %   z_t = Phibar*z_tL + Psibar*eps_t
    % where
    %   z_t = (hy_t,csi_t)

    C_GLM = [C1(ny+ncsi+1:end,:) C2(ny+ncsi+1:end,:)];
    C_z = [C1(1:ny+ncsi,:) C2(1:ny+ncsi,:)];

    % WarnState = warning('off', 'all');
    % Csi = reshape(kron(C_z',eye(nG))\C_GLM(:),nG,ny+ncsi);
    % warning(WarnState)
    Csi = reshape(pinv(kron(C_z',eye(nG)))*C_GLM(:),nG,ny+ncsi);

    % check reduction of system
    cr = round((C_GLM-Csi*C_z)/NumPrecision)*NumPrecision;
    if ~all(cr(:)==0)
        fprintf('Warning: System failed to reduce. State space includes GLM_t.\n')
        Sy = [eye(ny),zeros(ny,ncsi+nG)];
        Scsi = [zeros(ncsi,ny),eye(ncsi),zeros(ncsi,nG)];
        Svphi = [zeros(nG,ny+ncsi),eye(nG)];
    else
        Phi1 = C1(1:ny+ncsi,1:ny+ncsi)+C1(1:ny+ncsi,ny+ncsi+1:end)*Csi;
        Phi2 = C2(1:ny+ncsi,:);
        LQz_t = LQk_t(1:ny+ncsi);
        Sy = [eye(ny),zeros(ny,ncsi)];
        Scsi = [zeros(ncsi,ny),eye(ncsi)];
    end
else
    Phi1 = B1;
    Phi2 = B2;
    LQz_t = LQk_t;
    nz = length(LQz_t);
    Sy = [eye(ny),zeros(ny,nz-ny)];
    Scsi = [zeros(ncsi,ny),eye(ncsi),zeros(ncsi,nz-ny-ncsi)];
    SFLM = [zeros(nF,ny+ncsi),eye(nF),zeros(nF,nz-ny-ncsi-nF)];
    Svphi = [zeros(nG,ny+ncsi+nF),eye(nG),zeros(nG,nz-ny-ncsi-nF-nG)];
end

%% ------------------------------------------------------------------------

%% Prepare output
REE.Phi1 = Phi1;
REE.Phi2 = Phi2;
REE.z_t = LQz_t;
REE.eu = eu;
REE.Sy = Sy;
REE.Scsi = Scsi;
if exist('SFLM','var'),REE.SFLM = SFLM;end
if exist('Svphi','var'),REE.Svphi = Svphi;end
if exist('Phi_vphi_z','var'),REE.Phi_vphi_z = Phi_vphi_z;end
if exist('Phi_vphi_vphi','var'),REE.Phi_vphi_vphi = Phi_vphi_vphi;end
if exist('Phi_vphi_eps','var'),REE.Phi_vphi_eps = Phi_vphi_eps;end
varargout{1} = REE;
if nargout==2
    varargout{2} = LQz_t;
end

%% ------------------------------------------------------------------------

