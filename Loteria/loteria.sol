// SPDX-License-Identifier: MIT
pragma solidity >=0.4.4 <0.8.0;
pragma experimental ABIEncoderV2;
import "./ERC20.sol";

contract Loteria{

    //Instancia del contrato del token
    ERC20Basic private token;

    //Direcciones
    address public owner;
    address public contrato;

    //Numero de tokens a crear
    uint public tokens_creados = 10000;

    //Evento de compra de tokens
    event ComprandoTokens(uint, address);

    constructor() public{
        token = new ERC20Basic(tokens_creados);
        owner = msg.sender;
        contrato = address(this);
    }

    // ------------ TOKEN ------------

    //Establecer el precio de los tokens en ether
    function PrecioTokens(uint _numTokens) internal pure returns(uint){
        return _numTokens*(1 ether);
    }

    //Generar mas tokens por la loteria
    function GeneraTokens(uint _numTokens) public Unicamente(msg.sender){
        token.increaseTotalSuply(_numTokens);
    }

    //Modificador para controlar las funciones ejecutables por disney
    modifier Unicamente(address _direccion){
        require(_direccion == owner, "No tienes permisos para ejecutar esta funcion.");
        _;
    }

    // Comprar tokens para comprar boletos/tickets para la loteria
    function CompraTokens(uint _numTokens) public payable {
        uint precio_token = PrecioTokens(_numTokens);
        //Se requiere que el valor de ethers pagados sea equivlente al coste
        require(msg.value >= precio_token, "Compra menos tokens o paga con mas Ethers.");
        //Diferencia a pagar
        uint returnValue = msg.value - precio_token;
        //Transferencia de la diferencia
        msg.sender.transfer(returnValue);
        //Obtener el balance de tokens del contrato
        uint Balance = TokensDisponibles();
        //Filtro para evaluar los tokens a comprar con los tokens disponibles
        require(_numTokens <= Balance, "Compra un numero de tokens que puedas, no hay tanto.");
        //Transferencia de tokens al comprador
        token.transfer(msg.sender, _numTokens);
        emit ComprandoTokens(_numTokens, msg.sender);
    }

    //Balance de tokens en el contrato de loteria (Disponibles)
    function TokensDisponibles() public view returns(uint){
        return token.balanceOf(contrato);
    }

    //Obtener el balance de tokens acumulados en el Pozo
    function Pozo() public view returns(uint){
        return token.balanceOf(owner);
    }

    //Balance de Tokens de una persona
    function MisTokens() public view returns(uint){
        return token.balanceOf(msg.sender);
    }

    // ------ LOTERIA ------

    //Precio del boleto en tokens
    uint public PrecioBoleto = 5;

    //Relacion entre la persona que compra los boletos y los numeros de los boletos
    mapping(address => uint[]) idPersona_boletos;
    //Relacion para identificar al ganador
    mapping(uint => address) ADN_boleto;
    //Numero aleatorio
    uint randNonce = 0;
    //Registro de boletos generados
    uint[] boletos_comprados;

    //Eventos
    event boleto_comprado(uint);
    event boleto_ganador(uint);

    //Funcion para comprar boletos de loteria
    function CompraBoleto(uint _boletos) public {
        //Precio total de los boletos a comprar
        uint precio_total = _boletos * PrecioBoleto;
        //Filtrado de los tokens a pagar
        require(precio_total <= MisTokens(), "Necesitas mas tokens, no te alcanza.");
        //Transferencia de tokens al owner -> Contiene el pozo total
        token.transferencia_loteria(msg.sender, owner, precio_total);

        for(uint i = 0; i < _boletos; i++){
            uint random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % 10000;
            randNonce++;
            //Almacenamos los datos de los boletos
            idPersona_boletos[msg.sender].push(random);
            //Numero de boleto comprado
            boletos_comprados.push(random);
            //Asignacion del ADN del boleto para tener un ganador
            ADN_boleto[random] = msg.sender;
            emit boleto_comprado(random);
        }
    }

    //Visualizar el numero de boletos de una persona
    function TusBoletos() public view returns(uint [] memory){
        return idPersona_boletos[msg.sender];
    }

    //Generar un ganador y ingresarle los Tokens
    function GenerarGanador() public Unicamente(msg.sender){
        //Debe haber mas de 1 boleto comprado
        require(boletos_comprados.length > 0, "No hay boletos comprados");
        uint longitud = boletos_comprados.length;
        //Aleatoriamente elijo un numero entre 0 y la longitud (del array)
        uint posicion_array = uint (uint(keccak256(abi.encodePacked(block.timestamp))) % longitud);
        //Seleccion de numero aleatorio mediante la posicion del array aleatoria
        uint eleccion = boletos_comprados[posicion_array];
        emit boleto_ganador(eleccion);
        //Enviarle el pozo al ganador
        address direccion_ganador = ADN_boleto[eleccion];
        token.transferencia_loteria(msg.sender, direccion_ganador, Pozo());
    }

    //Devolucion de los tokens (Tokens x Ethers)
    function DevolverTokens(uint _numTokens) public payable {
        //El numero de tokens a devolver debe ser mayor a 0
        require(_numTokens > 0, "No podes devolver 0 tokens.");
        //El usuario debe tener esa cantidad de tokens a devolver
        require(_numTokens <= MisTokens(), "No tenes esos tokens.");
        // 1. El cliente devuelve esos tokens.
        token.transferencia_loteria(msg.sender, contrato, _numTokens);
        // 2. La Loteria les paga los tokens devueltos.
        msg.sender.transfer(PrecioTokens(_numTokens));

    }
}

