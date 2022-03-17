// SPDX-License-Identifier: MIT
pragma solidity >=0.4.4 <0.8.0;
pragma experimental ABIEncoderV2;
import "./OperacionesBasicas.sol";
import "./ERC20.sol";

//Contrato para la compañia de seguros
contract InsuranceFactory is OperacionesBasicas{

    constructor () public {
        token = new ERC20Basic(100);
        Insurance = address(this);
        Aseguradora = msg.sender;
    }

    struct cliente {
        address DireccionCliente;
        bool AutorizacionCliente;
        //Su servicio
        address DireccionContrato;
    }

    struct servicio {
        string NombreServicio;
        uint PrecioTokensServicio;
        bool EstadoServicio;
    }

    struct lab {
        address DireccionContratoLab;
        bool ValidacionLab;
    }

    //Instancia del contrato token
    ERC20Basic private token;

    //Direccion del seguro/insurance
    address Insurance;
    //Recibir pagos de los asegurados
    address payable public Aseguradora;

    //Mapeos y array para clientes, servicios y laboratorios
    mapping (address => cliente) public MappingAsegurados;
    mapping (string => servicio) public MappingServicios;
    mapping (address => lab) public MappingLab;

    //Arrays para guardar clientes, servicios y laboratorios
    address [] DireccionesAsegurados;
    string  [] private nombreServicios;
    address [] DireccionesLaboratorios;

    function FuncionUnicamenteAsegurados(address _direccionAsegurado) public view {
        require(MappingAsegurados[_direccionAsegurado].AutorizacionCliente == true, "Direccion de Asegurado NO autorizada.");
    }

    //Modificadores y restricciones sobre asegurados y aseguradoras
    modifier UnicamenteAsegurados(address _direccionAsegurado){
        FuncionUnicamenteAsegurados(_direccionAsegurado);
        _;
    }

    modifier UnicamenteAseguradora(address _direccionAseguradora){
        require(Aseguradora == _direccionAseguradora, "Direccion de Aseguradora NO autorizada.");
        _;
    }

    modifier Asegurado_o_Aseguradora(address _direccionAsegurado, address _direccionEntrante){
        require((MappingAsegurados[_direccionEntrante].AutorizacionCliente == true && _direccionAsegurado == _direccionEntrante) || Aseguradora == _direccionEntrante, "Solamente compania de seguros o asegurados.");
        _;    
    }

    //Eventos
    event EventoComprado(uint256);     
    event EventoServicioProporcionado(address, string, uint256);
    event EventoLaboratorioCreado(address, address);
    event EventoAseguradoCreado(address, address);
    event EventoBajaAsegurado(address);
    event EventoServicioCreado(string, uint256);
    event EventoBajaServicio(string);

    function creacionLab() public {

        DireccionesLaboratorios.push(msg.sender);
        address direccionLab = address(new Laboratorio(msg.sender, Insurance));
        lab memory Laboratorio = lab(direccionLab, true);
        MappingLab[msg.sender] = Laboratorio;
        emit EventoLaboratorioCreado(msg.sender, direccionLab);
    }

    function creacionContratoAsegurado() public {
        DireccionesAsegurados.push(msg.sender);
        address direccionAsegurado = address(new InsuranceHealthRecord(msg.sender, token, Insurance, Aseguradora));
        MappingAsegurados[msg.sender] = cliente(msg.sender, true, direccionAsegurado);
        emit EventoAseguradoCreado(msg.sender, direccionAsegurado);
    }

    function Laboratorios() public view UnicamenteAseguradora(msg.sender) returns (address [] memory){
        return DireccionesLaboratorios;
    }

    function Asegurados() public view UnicamenteAseguradora(msg.sender) returns (address [] memory){
        return DireccionesAsegurados;
    }

    function consultarHistorialAsegurado(address _direccionAsegurado, address _direccionConsultor) public view Asegurado_o_Aseguradora(_direccionAsegurado, _direccionConsultor) returns (string memory){
        string memory historial = "";
        address direccionContratoAsegurado = MappingAsegurados[_direccionAsegurado].DireccionContrato;

        for(uint i = 0; i < nombreServicios.length; i++){
            if(MappingServicios[nombreServicios[i]].EstadoServicio && InsuranceHealthRecord(direccionContratoAsegurado).ServicioEstadoAsegurado(nombreServicios[i]) == true){
                (string memory nombreServicio, uint precioServicio) = InsuranceHealthRecord(direccionContratoAsegurado).HistorialAsegurado(nombreServicios[i]);
                historial = string(abi.encodePacked(historial, "(", nombreServicio, ", " , uint2str(precioServicio), ") -------- "));
            }
        }

        return historial;
    }

    function darBajaCliente(address _direccionAsegurado) public UnicamenteAseguradora(msg.sender) {
        MappingAsegurados[_direccionAsegurado].AutorizacionCliente = false;
        InsuranceHealthRecord(MappingAsegurados[_direccionAsegurado].DireccionContrato).darBaja;
        emit EventoBajaAsegurado(_direccionAsegurado);
    }

    function nuevoServicio(string memory _nombreServicio, uint256 _precioServicio) public UnicamenteAseguradora(msg.sender){
        MappingServicios[_nombreServicio] = servicio(_nombreServicio, _precioServicio, true);
        nombreServicios.push(_nombreServicio);
        emit EventoServicioCreado(_nombreServicio, _precioServicio);
    }

    function darBajaServicio(string memory _nombreServicio) public UnicamenteAseguradora(msg.sender){
        require(ServicioEstado(_nombreServicio) == true, "No se ha dado de alta el servicio.");
        MappingServicios[_nombreServicio].EstadoServicio = false;
        emit EventoBajaServicio(_nombreServicio);
    }

    function ServicioEstado(string memory _nombreServicio) public view returns(bool){
        return MappingServicios[_nombreServicio].EstadoServicio;
    }

    function getPrecioServicio(string memory _nombreServicio) public view returns(uint256){
        require(ServicioEstado(_nombreServicio) == true, "Servicio no disponible.");
        return MappingServicios[_nombreServicio].PrecioTokensServicio;
    }

    function ConsultarServiciosActivos() public view returns (string [] memory){
        string [] memory ServiciosActivos = new string[](nombreServicios.length);
        uint contador = 0;

        for(uint i = 0; i < nombreServicios.length; i++){
            if(ServicioEstado(nombreServicios[i]) == true){
                ServiciosActivos[contador] = nombreServicios[i];
                contador++;
            }
        }
        return ServiciosActivos;
    }

    function compraTokens(address _asegurado, uint _numTokens) public payable UnicamenteAsegurados(_asegurado){
        uint256 Balance = balanceOf();
        require(_numTokens <= Balance, "No hay tantos tokens.");
        require(_numTokens > 0, "Compra un numero positivo de tokens.");

        token.transfer(msg.sender, _numTokens);
        emit EventoComprado(_numTokens);
    }

    function balanceOf() public view returns (uint256 tokens){
        return (token.balanceOf(Insurance)); 
    }

    function generarTokens(uint _numTokens) public UnicamenteAseguradora(msg.sender){
        token.increaseTotalSuply(_numTokens);
    }

}

contract InsuranceHealthRecord is OperacionesBasicas{

    enum Estado { alta, baja }

    struct Owner{
        address direccionPropietario;
        uint saldoPropietario;
        Estado estado;
        ERC20Basic tokens;
        address insurance;
        address payable aseguradora;
    }

    Owner propietario;

    constructor (address _owner, ERC20Basic _token, address _insurance, address payable _aseguradora) public {
        propietario.direccionPropietario = _owner;
        propietario.saldoPropietario = 0;
        propietario.estado = Estado.alta;
        propietario.tokens = _token;
        propietario.insurance = _insurance;
        propietario.aseguradora = _aseguradora;
    }

    //Servicios pendientes (historico)
    struct ServiciosSolicitados{
        string nombreServicio;
        uint256 precioServicio;
        bool estadoServicio;
    }

    //Servicio con laboratorio asignado
    struct ServiciosSolicitadosLab{
        string nombreServicio;
        uint256 precioServicio;
        address direccionLab;
    }

    mapping (string => ServiciosSolicitados) historialAsegurado;
    ServiciosSolicitadosLab [] historialAseguradoLaboratorio;
    ServiciosSolicitados [] historialServiciosSolicitados;

    event EventoSelfDestruct(address);
    event EventoDevolverToken(address ,uint256);
    event EventoServicioPagado(address, string, uint256);
    event EventoPeticionServicioLab(address, address, string);

    modifier Unicamente(address _direccion){
        require(_direccion == propietario.direccionPropietario, "No eres el asegurado de la poliza.");
        _;
    }

    function HistorialAseguradoLaboratorio() public view returns(ServiciosSolicitadosLab [] memory){
        return historialAseguradoLaboratorio;
    }

    function HistorialAsegurado(string memory _servicio) public view returns(string memory nombreServicio, uint precioServicio){
        return (historialAsegurado[_servicio].nombreServicio, historialAsegurado[_servicio].precioServicio);
    }

    function ServicioEstadoAsegurado(string memory _servicio) public view returns(bool){
        return historialAsegurado[_servicio].estadoServicio;
    }

    function darBaja() public Unicamente(msg.sender){
        emit EventoSelfDestruct(msg.sender);
        selfdestruct(msg.sender);
    }

    function CompraTokens(uint _numTokens) payable public Unicamente(msg.sender){
        require(_numTokens > 0, "Necesitas comprar un numero de tokens positivo.");
        uint coste = calcularPrecioTokens(_numTokens);
        require(msg.value >= coste, "Compra menos tokens, no te alcanza.");
        uint returnValue = msg.value - coste;
        msg.sender.transfer(returnValue);
        InsuranceFactory(propietario.insurance).compraTokens(msg.sender, _numTokens);
    }

    function balanceOf() public view Unicamente(msg.sender) returns (uint256 _balance){
        return (propietario.tokens.balanceOf(address(this))); 
    }

    function devolverTokens(uint _numTokens) public payable Unicamente(msg.sender){
        require(_numTokens > 0, "Necesitas devolver un numero positivo de tokens.");
        require(_numTokens <= balanceOf(), "No tienes los tokens que queres devolver.");
        propietario.tokens.transfer(propietario.aseguradora, _numTokens);
        msg.sender.transfer(calcularPrecioTokens(_numTokens));

        emit EventoDevolverToken(msg.sender, _numTokens);
    }

    //Quiero hacer X estudio
    function peticionServicio(string memory _servicio) public Unicamente(msg.sender){
        require(InsuranceFactory(propietario.insurance).ServicioEstado(_servicio) == true, "El servicio no se ha dado de alta en la aseguradora.");
        uint256 pagoTokens = InsuranceFactory(propietario.insurance).getPrecioServicio(_servicio);
        require(pagoTokens <= balanceOf(), "Necesitas comprar mas tokens, no te alcanza para el servicio.");
        propietario.tokens.transfer(propietario.aseguradora, pagoTokens);
        historialAsegurado[_servicio] = ServiciosSolicitados(_servicio, pagoTokens, true);
        emit EventoServicioPagado(msg.sender, _servicio, pagoTokens);
    }

    //Quiero hacer X estudio en X Laboratorio
    function peticionServicioLab(address _direccionLab, string memory _servicio) public payable Unicamente(msg.sender){
        Laboratorio contratoLab = Laboratorio(_direccionLab);
        require(msg.value == contratoLab.ConsultarPrecioServicios(_servicio) * 1 ether, "Operacion invalida");
        contratoLab.DarServicio(msg.sender, _servicio);
        payable(contratoLab.DireccionLab()).transfer(contratoLab.ConsultarPrecioServicios(_servicio) * 1 ether);
        historialAseguradoLaboratorio.push(ServiciosSolicitadosLab(_servicio, contratoLab.ConsultarPrecioServicios(_servicio), _direccionLab));
        emit EventoPeticionServicioLab(_direccionLab, msg.sender, _servicio);
    }
}

contract Laboratorio is OperacionesBasicas {

    address public DireccionLab;
    address private ContratoAseguradora;

    constructor (address _account, address _direccionContratoAseguradora) public {
        DireccionLab = _account;
        ContratoAseguradora = _direccionContratoAseguradora;
    }

    mapping(address => string) public ServicioSolicitado;

    address [] public PeticionesServicios;

    mapping(address => ResultadoServicio) ResultadosServiciosLab;

    struct ResultadoServicio{
        string diagnosticoServicio;
        string codigoIPFS;
    }

    string [] nombreServiciosLab;

    mapping (string => ServicioLab) public serviciosLab;
    
    struct ServicioLab{
        string nombreServicio;
        uint precio;
        bool enFuncionamiento;
    }

    event EventoServicioFuncionando(string, uint);
    event EventoDarServicio(address, string);

    modifier UnicamenteLab(address _direccion){
        require(_direccion == DireccionLab, "No existen permisos en el sistema para ejecutar esta funcion");
        _;
    }

    function NuevoServicioLab(string memory _servicio, uint _precio) public UnicamenteLab(msg.sender){
        serviciosLab[_servicio] = ServicioLab(_servicio, _precio, true);
        nombreServiciosLab.push(_servicio);
        emit EventoServicioFuncionando(_servicio, _precio);
    }

    function ConsultarServicios() public view returns(string [] memory){
        return nombreServiciosLab;
    }

    function ConsultarPrecioServicios(string memory _servicio) public view returns(uint){
        return serviciosLab[_servicio].precio;
    }

    function DarServicio(address _direccionAsegurado, string memory _servicio) public {
        InsuranceFactory IF = InsuranceFactory(ContratoAseguradora);
        //Pasa el filtro de que es un asegurado de la aseguradora, evitar terceros
        IF.FuncionUnicamenteAsegurados(_direccionAsegurado);
        require(serviciosLab[_servicio].enFuncionamiento == true, "El servicio no se encuentra disponible.");
        ServicioSolicitado[_direccionAsegurado] = _servicio;
        PeticionesServicios.push(_direccionAsegurado);
        emit EventoDarServicio(_direccionAsegurado, _servicio);
    }

    function DarResultados(address _direccionAsegurado, string memory _diagnostico, string memory _codigoIPFS) public UnicamenteLab(msg.sender){
        ResultadosServiciosLab[_direccionAsegurado] = ResultadoServicio(_diagnostico, _codigoIPFS);
    }

    function VisualizarResultados(address _direccionAsegurado) public view returns (string memory _diagnostico, string memory _codigoIPFS){
        _diagnostico = ResultadosServiciosLab[_direccionAsegurado].diagnosticoServicio;
        _codigoIPFS = ResultadosServiciosLab[_direccionAsegurado].codigoIPFS;
    } 

}